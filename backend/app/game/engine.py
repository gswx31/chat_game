"""Server-authoritative game engine. One asyncio task per active room.

State model:
- In-memory: round state, scores, players, used questions (single-worker MVP).
- Redis: ``room:{id}:answered:{round}`` SETNX lock (race-safe first answer),
  ``room:{id}:state`` Hash + ``room:{id}:scores`` ZSet snapshot
  (groundwork for multi-worker; not authoritative yet).
"""

from __future__ import annotations

import asyncio
import logging
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import TYPE_CHECKING, Any, Awaitable, Callable

from sqlalchemy import func, select, update

from app.db.models import (
    GameResult,
    Question,
    QuestionSet,
    QuestionSetItem,
    Room,
    RoomMember,
    User,
)
from app.db.session import SessionLocal
from app.game.chosung import build_hint
from app.game.results import is_worth_recording, rank_players
from app.questions.normalize import normalize_answer
from app.redis_client import get_redis
from app.ws import protocol as P

if TYPE_CHECKING:
    from redis.asyncio import Redis


log = logging.getLogger(__name__)

Broadcast = Callable[[str, dict[str, Any]], Awaitable[None]]

# How long a kick keeps someone out of the room.
BAN_TTL_SECONDS = 60 * 60 * 24


@dataclass
class RoomConfig:
    win_score: int
    round_seconds: int
    categories: list[str]
    difficulty_min: int
    difficulty_max: int
    owner_id: str | None
    question_set_id: str | None = None  # None = system questions; set id = use that map
    room_name: str = ''
    room_code: str = ''


# "ㅅㅋ" is the 초성 of 스킵: quicker to type, and never a real answer (answers are whole words).
SKIP_WORDS = frozenset({"스킵", "ㅅㅋ"})


def is_skip_command(text: str) -> bool:
    """Typing just "스킵" or "ㅅㅋ" (also "스킵!" or " ㅅㅋ ") in the chat is a vote to skip the
    question, for players who cannot easily reach the skip button while the keyboard is up."""
    return normalize_answer(text) in SKIP_WORDS


class GameEngine:
    def __init__(self, room_id: str, cfg: RoomConfig, broadcast: Broadcast) -> None:
        self.room_id = room_id
        self.cfg = cfg
        self._broadcast = broadcast
        self.task: asyncio.Task[None] | None = None
        self.status: str = "waiting"  # waiting | playing | ended

        self.players: dict[str, str] = {}  # user_id -> nickname
        self.scores: dict[str, int] = {}
        self.used_question_ids: set[str] = set()

        self.current_round = 0
        self.current_question: Question | None = None
        self.round_deadline: float = 0.0
        # Set once the halfway hint goes out, so a player who reconnects later still sees it.
        self.current_hint: str | None = None
        self.first_answerer: str | None = None
        self.skip_votes: set[str] = set()
        self._round_event: asyncio.Event = asyncio.Event()
        # Users the owner just kicked. The WS finally block consults this so
        # we don't double-broadcast both `player_kicked` and `player_leave`.
        self.recent_kicks: set[str] = set()
        # Kicked users, kept until the ban expires. `recent_kicks` is cleared as
        # soon as the socket tears down, so without this a kicked client simply
        # reconnected (its backoff fires one second later) and walked back in.
        self.banned: set[str] = set()
        self._grace_tasks: dict[str, asyncio.Task] = {}

    # ----- presence -----
    def register_player(self, user_id: str, nickname: str) -> None:
        self.players[user_id] = nickname
        self.scores.setdefault(user_id, 0)

    def unregister_player(self, user_id: str) -> None:
        self.players.pop(user_id, None)
        self.skip_votes.discard(user_id)

    def start_grace(self, uid: str, nickname: str) -> None:
        """During 'playing': hold the player slot for 20 s before evicting."""
        self.cancel_grace(uid)
        self.skip_votes.discard(uid)

        async def _timeout() -> None:
            await asyncio.sleep(20)
            self.unregister_player(uid)
            self._grace_tasks.pop(uid, None)
            await self._broadcast(
                self.room_id,
                {"type": P.S_PLAYER_LEAVE, "user_id": uid, "nickname": nickname},
            )

        self._grace_tasks[uid] = asyncio.create_task(_timeout())

    def cancel_grace(self, uid: str) -> None:
        task = self._grace_tasks.pop(uid, None)
        if task:
            task.cancel()

    def is_in_grace(self, uid: str) -> bool:
        return uid in self._grace_tasks

    # ----- bans -----
    def _ban_key(self) -> str:
        return f"room:{self.room_id}:banned"

    async def ban(self, user_id: str) -> None:
        """Bar a kicked user from rejoining. Mirrored into Redis so the ban
        outlives this engine instance (the registry drops idle engines)."""
        self.banned.add(user_id)
        try:
            redis = get_redis()
            await redis.sadd(self._ban_key(), user_id)
            await redis.expire(self._ban_key(), BAN_TTL_SECONDS)
        except Exception:  # noqa: BLE001 — in-memory set still enforces it
            log.exception("failed to persist ban room=%s user=%s", self.room_id, user_id)

    async def is_banned(self, user_id: str) -> bool:
        if user_id in self.banned:
            return True
        try:
            redis = get_redis()
            return bool(await redis.sismember(self._ban_key(), user_id))
        except Exception:  # noqa: BLE001
            log.exception("ban lookup failed room=%s", self.room_id)
            return False

    @property
    def has_players(self) -> bool:
        return bool(self.players)

    # ----- snapshot -----
    def snapshot(self) -> dict[str, Any]:
        current: dict[str, Any] | None = None
        if self.status == "playing" and self.current_question:
            current = {
                "round": self.current_round,
                "prompt": self.current_question.prompt,
                "category": self.current_question.category,
                "difficulty": self.current_question.difficulty,
                "deadline_ts": self.round_deadline,
                "hint": self.current_hint,
            }
        return {
            "type": P.S_ROOM_STATE,
            "status": self.status,
            "win_score": self.cfg.win_score,
            "round_seconds": self.cfg.round_seconds,
            "owner_id": self.cfg.owner_id,
            "room_name": self.cfg.room_name,
            "room_code": self.cfg.room_code,
            "players": self._scoreboard(),
            "current": current,
        }

    def _scoreboard(self) -> list[dict[str, Any]]:
        rows = [
            {
                "user_id": uid,
                "nickname": self.players.get(uid, "(나감)"),
                "score": score,
                "online": uid in self.players,
            }
            for uid, score in self.scores.items()
        ]
        rows.sort(key=lambda r: r["score"], reverse=True)
        return rows

    # ----- control -----
    async def start(self) -> bool:
        if self.status != "waiting":
            return False
        self.status = "playing"
        self.task = asyncio.create_task(self._run(), name=f"game:{self.room_id}")
        return True

    async def reset_for_rematch(self) -> bool:
        """Return engine to 'waiting' so the same room can host another game.
        Zeroes scores for current players, clears used questions, resets round state.
        Refuses while a game is still in progress."""
        if self.status == "playing":
            return False
        self.status = "waiting"
        for task in self._grace_tasks.values():
            task.cancel()
        self._grace_tasks.clear()
        self.scores = {uid: 0 for uid in self.players}
        self.used_question_ids.clear()
        self.current_round = 0
        self.current_question = None
        self.current_hint = None
        self.round_deadline = 0.0
        self.first_answerer = None
        self.skip_votes.clear()
        self._round_event.clear()
        self.task = None
        return True

    async def submit_chat(self, user_id: str, text: str) -> bool:
        """Return True if this chat was the winning answer."""
        if (
            self.status != "playing"
            or self.current_question is None
            or self.first_answerer is not None
        ):
            return False
        norm = normalize_answer(text)
        q = self.current_question
        if norm != q.answer_normalized and norm not in (q.accepted_answers or []):
            return False
        redis = get_redis()
        key = f"room:{self.room_id}:answered:{self.current_round}"
        won = await redis.set(key, user_id, nx=True, ex=self.cfg.round_seconds + 10)
        if not won:
            return False
        self.first_answerer = user_id
        self._round_event.set()
        return True

    async def vote_skip(self, user_id: str) -> None:
        if (
            self.status != "playing"
            or self.current_question is None
            or self.first_answerer is not None
            or user_id in self.skip_votes
        ):
            return
        self.skip_votes.add(user_id)
        needed = self._skip_threshold()
        await self._broadcast(
            self.room_id,
            {"type": P.S_SKIP_PROGRESS, "votes": len(self.skip_votes), "needed": needed},
        )
        if len(self.skip_votes) >= needed:
            self._round_event.set()

    def _skip_threshold(self) -> int:
        """Votes needed to skip: more than half the room, so two players must both agree."""
        return max(1, len(self.players) // 2 + 1)

    # ----- main loop -----
    async def _run(self) -> None:
        redis = get_redis()
        try:
            # Increment play_count on the question set when game starts
            if self.cfg.question_set_id:
                async with SessionLocal() as db:
                    await db.execute(
                        update(QuestionSet)
                        .where(QuestionSet.id == self.cfg.question_set_id)
                        .values(play_count=QuestionSet.play_count + 1)
                    )
                    await db.commit()

            await self._broadcast(
                self.room_id,
                {"type": P.S_GAME_START, "win_score": self.cfg.win_score},
            )
            while not self._winner_reached():
                if not self.players:
                    # Everyone left; end the game gracefully.
                    await self._broadcast(
                        self.room_id,
                        {"type": P.S_ERROR, "message": "모두 나가서 게임을 종료합니다"},
                    )
                    break
                self.current_round += 1
                q = await self._pick_question()
                if q is None:
                    await self._broadcast(
                        self.room_id,
                        {"type": P.S_ERROR, "message": "준비된 문제를 모두 풀었어요"},
                    )
                    break
                await self._run_round(q, redis)
                await asyncio.sleep(3)

            for task in self._grace_tasks.values():
                task.cancel()
            self._grace_tasks.clear()
            self.status = "ended"
            winner_id = max(self.scores.items(), key=lambda kv: kv[1])[0] if self.scores else None
            # Persist BEFORE announcing: a client that reacts to game_over by calling
            # GET /rooms/{id} must already see status="ended". A failed write is
            # logged but must never swallow the game_over the players are waiting for.
            try:
                await self._persist_final(winner_id)
            except Exception:  # noqa: BLE001
                log.exception("persisting final scores failed room=%s", self.room_id)
            await self._broadcast(
                self.room_id,
                {
                    "type": P.S_GAME_OVER,
                    "scores": self._scoreboard(),
                    "winner_id": winner_id,
                },
            )
        except Exception:  # noqa: BLE001
            # Log server-side — this used to vanish silently, so a crashed game
            # left no trace anywhere. Clients get a generic message; the raw
            # exception text can expose internals.
            log.exception("game engine crashed room=%s round=%s", self.room_id, self.current_round)
            await self._broadcast(
                self.room_id,
                {"type": P.S_ERROR, "message": "게임 진행 중 오류가 발생했어요"},
            )
            for task in self._grace_tasks.values():
                task.cancel()
            self._grace_tasks.clear()
            self.status = "ended"
        finally:
            # Release the engine if the room emptied out while we were running.
            # Clearing `task` first lets drop_if_empty see the loop as finished.
            self.task = None
            from app.game import registry  # late import: registry imports this module

            await registry.drop_if_empty(self.room_id)

    async def _run_round(self, q: Question, redis: "Redis") -> None:
        self.current_question = q
        self.current_hint = None
        self.first_answerer = None
        self.skip_votes.clear()
        self._round_event.clear()
        self.round_deadline = time.time() + self.cfg.round_seconds

        # Mirror current round state to Redis (snapshot for future multi-worker)
        await redis.hset(
            f"room:{self.room_id}:state",
            mapping={
                "round": str(self.current_round),
                "prompt": q.prompt,
                "deadline": str(self.round_deadline),
                "status": "playing",
            },
        )

        await self._broadcast(
            self.room_id,
            {
                "type": P.S_ROUND_START,
                "round": self.current_round,
                "prompt": q.prompt,
                "category": q.category,
                "difficulty": q.difficulty,
                "deadline_ts": self.round_deadline,
            },
        )

        half = self.cfg.round_seconds / 2
        try:
            await asyncio.wait_for(self._round_event.wait(), timeout=half)
        except asyncio.TimeoutError:
            # halfway: reveal hint (custom, else auto 초성 / masked shape)
            hint = q.hint or build_hint(q.answer)
            self.current_hint = hint
            await self._broadcast(
                self.room_id,
                {"type": P.S_HINT, "round": self.current_round, "hint": hint},
            )
            try:
                await asyncio.wait_for(self._round_event.wait(), timeout=half)
            except asyncio.TimeoutError:
                pass

        if self.first_answerer:
            uid = self.first_answerer
            self.scores[uid] = self.scores.get(uid, 0) + 1
            await self._broadcast(
                self.room_id,
                {
                    "type": P.S_CORRECT,
                    "round": self.current_round,
                    "user_id": uid,
                    "nickname": self.players.get(uid, "?"),
                    "answer": q.answer,
                },
            )
        else:
            reason = "skipped" if len(self.skip_votes) >= self._skip_threshold() else "timeout"
            await self._broadcast(
                self.room_id,
                {
                    "type": P.S_ROUND_END,
                    "round": self.current_round,
                    "reason": reason,
                    "answer": q.answer,
                },
            )

        # Update scores zset + broadcast
        if self.scores:
            await redis.zadd(
                f"room:{self.room_id}:scores",
                {uid: score for uid, score in self.scores.items()},
            )
        await self._broadcast(
            self.room_id,
            {"type": P.S_SCORE_UPDATE, "scores": self._scoreboard()},
        )

        # Keep the idle-cleanup sweeper from culling an active long game.
        async with SessionLocal() as db:
            await db.execute(
                update(Room).where(Room.id == self.room_id).values(
                    last_active_at=datetime.now(UTC)
                )
            )
            await db.commit()

    async def _pick_question(self) -> Question | QuestionSetItem | None:
        async with SessionLocal() as db:
            if self.cfg.question_set_id:
                return await self._pick_from_set(db, self.cfg.question_set_id)
            return await self._pick_from_system(db)

    async def _pick_from_set(self, db: Any, set_id: str) -> QuestionSetItem | None:
        stmt = select(QuestionSetItem).where(QuestionSetItem.set_id == set_id)
        if self.used_question_ids:
            stmt = stmt.where(QuestionSetItem.id.notin_(self.used_question_ids))
        if self.cfg.categories:
            stmt = stmt.where(QuestionSetItem.category.in_(self.cfg.categories))
        stmt = stmt.where(
            QuestionSetItem.difficulty.between(self.cfg.difficulty_min, self.cfg.difficulty_max)
        ).order_by(func.random()).limit(1)
        q = await db.scalar(stmt)
        if q:
            self.used_question_ids.add(q.id)
        return q

    async def _pick_from_system(self, db: Any) -> Question | None:
        stmt = select(Question).where(
            Question.difficulty.between(self.cfg.difficulty_min, self.cfg.difficulty_max)
        )
        if self.used_question_ids:
            stmt = stmt.where(Question.id.notin_(self.used_question_ids))
        if self.cfg.categories:
            stmt = stmt.where(Question.category.in_(self.cfg.categories))
        stmt = stmt.order_by(func.random()).limit(1)
        q = await db.scalar(stmt)
        if q:
            self.used_question_ids.add(q.id)
        return q

    def _winner_reached(self) -> bool:
        return any(score >= self.cfg.win_score for score in self.scores.values())

    async def _persist_final(self, winner_id: str | None = None) -> None:
        async with SessionLocal() as db:
            room = await db.get(Room, self.room_id)
            if room:
                room.status = "ended"
                room.ended_at = datetime.now(UTC)
            if self.scores:
                from sqlalchemy import case as sa_case
                await db.execute(
                    update(RoomMember)
                    .where(RoomMember.room_id == self.room_id)
                    .values(
                        score=sa_case(
                            self.scores,
                            value=RoomMember.user_id,
                            else_=RoomMember.score,
                        )
                    )
                )
            await self._record_history(db, room, winner_id)
            await db.commit()

    async def _record_history(self, db, room: Room | None, winner_id: str | None) -> None:
        """Append this game to every participant's permanent history (see GameResult)."""
        if not is_worth_recording(self.scores):
            return
        names = dict(
            (
                await db.execute(
                    select(User.id, User.nickname).where(User.id.in_(list(self.scores)))
                )
            ).all()
        )
        # Only players that still exist as users (a deleted guest would break the FK).
        ranked = [r for r in rank_players(self.scores) if r.user_id in names]
        for r in ranked:
            db.add(
                GameResult(
                    user_id=r.user_id,
                    room_name=(room.name if room else self.cfg.room_name)[:60],
                    room_code=(room.code if room else self.cfg.room_code)[:6],
                    score=r.score,
                    rank=r.rank,
                    player_count=len(self.scores),
                    win_score=self.cfg.win_score,
                    winner_nickname=names.get(winner_id) if winner_id else None,
                )
            )
