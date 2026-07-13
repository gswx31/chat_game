"""Server-authoritative game engine. One asyncio task per active room.

State model:
- In-memory: round state, scores, players, used questions (single-worker MVP).
- Redis: ``room:{id}:answered:{round}`` SETNX lock (race-safe first answer),
  ``room:{id}:state`` Hash + ``room:{id}:scores`` ZSet snapshot
  (groundwork for multi-worker; not authoritative yet).
"""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import TYPE_CHECKING, Any, Awaitable, Callable

from sqlalchemy import func, select, update

from app.db.models import Question, QuestionSet, QuestionSetItem, Room, RoomMember
from app.db.session import SessionLocal
from app.game.chosung import korean_chosung
from app.questions.normalize import normalize_answer
from app.redis_client import get_redis
from app.ws import protocol as P

if TYPE_CHECKING:
    from redis.asyncio import Redis


Broadcast = Callable[[str, dict[str, Any]], Awaitable[None]]


@dataclass
class RoomConfig:
    win_score: int
    round_seconds: int
    categories: list[str]
    difficulty_min: int
    difficulty_max: int
    owner_id: str | None
    question_set_id: str | None = None  # None = system questions; set id = use that map


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
        self.first_answerer: str | None = None
        self.skip_votes: set[str] = set()
        self._round_event: asyncio.Event = asyncio.Event()
        # Users the owner just kicked. The WS finally block consults this so
        # we don't double-broadcast both `player_kicked` and `player_leave`.
        self.recent_kicks: set[str] = set()

    # ----- presence -----
    def register_player(self, user_id: str, nickname: str) -> None:
        self.players[user_id] = nickname
        self.scores.setdefault(user_id, 0)

    def unregister_player(self, user_id: str) -> None:
        self.players.pop(user_id, None)
        self.skip_votes.discard(user_id)

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
            }
        return {
            "type": P.S_ROOM_STATE,
            "status": self.status,
            "win_score": self.cfg.win_score,
            "round_seconds": self.cfg.round_seconds,
            "owner_id": self.cfg.owner_id,
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
        self.scores = {uid: 0 for uid in self.players}
        self.used_question_ids.clear()
        self.current_round = 0
        self.current_question = None
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
        n = len(self.players)
        return max(1, (n + 1) // 2)

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
                        {"type": P.S_ERROR, "message": "no more questions"},
                    )
                    break
                await self._run_round(q, redis)
                await asyncio.sleep(3)

            self.status = "ended"
            winner_id = max(self.scores.items(), key=lambda kv: kv[1])[0] if self.scores else None
            await self._broadcast(
                self.room_id,
                {
                    "type": P.S_GAME_OVER,
                    "scores": self._scoreboard(),
                    "winner_id": winner_id,
                },
            )
            await self._persist_final()
        except Exception as e:  # noqa: BLE001
            await self._broadcast(self.room_id, {"type": P.S_ERROR, "message": f"engine: {e}"})
            self.status = "ended"

    async def _run_round(self, q: Question, redis: "Redis") -> None:
        self.current_question = q
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
            # halfway: reveal hint (custom or auto chosung)
            hint = q.hint or korean_chosung(q.answer)
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

    async def _persist_final(self) -> None:
        async with SessionLocal() as db:
            room = await db.get(Room, self.room_id)
            if room:
                room.status = "ended"
                room.ended_at = datetime.now(UTC)
            for uid, score in self.scores.items():
                await db.execute(
                    update(RoomMember)
                    .where(RoomMember.room_id == self.room_id, RoomMember.user_id == uid)
                    .values(score=score)
                )
            await db.commit()
