"""Unit tests for GameEngine. The async game loop (_run) and DB picking are
not exercised here — those need an integration setup. We cover the pure-logic
parts: presence, scoreboard, snapshot, rematch reset, and submit_chat with a
fake Redis."""

from __future__ import annotations

from typing import Any

import pytest

from app.db.models import Question
from app.game.engine import GameEngine, RoomConfig, is_skip_command


@pytest.fixture
def cfg() -> RoomConfig:
    return RoomConfig(
        win_score=20,
        round_seconds=30,
        categories=[],
        difficulty_min=1,
        difficulty_max=5,
        owner_id="u1",
    )


@pytest.fixture
def engine(cfg: RoomConfig) -> GameEngine:
    sent: list[dict[str, Any]] = []

    async def fake_broadcast(_room_id: str, msg: dict[str, Any]) -> None:
        sent.append(msg)

    eng = GameEngine("room1", cfg, fake_broadcast)
    eng._sent = sent  # type: ignore[attr-defined]
    return eng


def test_register_initializes_score(engine: GameEngine):
    engine.register_player("u1", "alice")
    assert engine.scores["u1"] == 0
    assert engine.players["u1"] == "alice"


def test_unregister_preserves_score(engine: GameEngine):
    engine.register_player("u1", "alice")
    engine.scores["u1"] = 5
    engine.unregister_player("u1")
    assert "u1" not in engine.players
    assert engine.scores["u1"] == 5


def test_skip_needs_more_than_half_of_the_room(engine: GameEngine):
    assert engine._skip_threshold() == 1  # empty: floor 1
    needed = {}
    for n in range(1, 8):
        engine.register_player(f"u{n}", f"p{n}")
        needed[n] = engine._skip_threshold()
    # 2 players must both agree; from then on a strict majority
    assert needed == {1: 1, 2: 2, 3: 2, 4: 3, 5: 3, 6: 4, 7: 4}


@pytest.mark.parametrize("text", ["스킵", " 스킵 ", "스킵!", "스 킵", "스킵?!", "ㅅㅋ", " ㅅㅋ ", "ㅅㅋ!", "ㅅ ㅋ"])
def test_typing_skip_is_a_skip_command(text: str):
    assert is_skip_command(text)


@pytest.mark.parametrize("text", ["스킵해줘", "스킵 좀", "건너뛰기", "skip", "", "정답은 스킵", "ㅋㅋ", "ㅅㅋㅋ", "ㅅ"])
def test_other_text_is_not_a_skip_command(text: str):
    assert not is_skip_command(text)


def _playing(engine: GameEngine, *players: str) -> None:
    for p in players:
        engine.register_player(p, p)
    engine.status = "playing"
    engine.current_question = object()  # type: ignore[assignment]


@pytest.mark.asyncio
async def test_two_players_must_both_vote_to_skip(engine: GameEngine):
    _playing(engine, "u1", "u2")
    await engine.vote_skip("u1")
    assert not engine._round_event.is_set()
    assert engine._sent[-1] == {"type": "skip_progress", "votes": 1, "needed": 2}
    await engine.vote_skip("u1")  # the same player twice counts once
    assert not engine._round_event.is_set()
    await engine.vote_skip("u2")
    assert engine._round_event.is_set()


@pytest.mark.asyncio
async def test_three_players_skip_with_two_votes(engine: GameEngine):
    _playing(engine, "u1", "u2", "u3")
    await engine.vote_skip("u1")
    assert not engine._round_event.is_set()
    await engine.vote_skip("u3")
    assert engine._round_event.is_set()


@pytest.mark.asyncio
async def test_a_skip_vote_outside_a_running_question_is_ignored(engine: GameEngine):
    engine.register_player("u1", "a")
    await engine.vote_skip("u1")  # waiting room: nothing to skip
    assert engine.skip_votes == set()
    assert engine._sent == []


def test_winner_not_reached_below(engine: GameEngine):
    engine.register_player("u1", "a")
    engine.scores["u1"] = engine.cfg.win_score - 1
    assert not engine._winner_reached()


def test_winner_reached_at_target(engine: GameEngine):
    engine.register_player("u1", "a")
    engine.scores["u1"] = engine.cfg.win_score
    assert engine._winner_reached()


def test_scoreboard_sorted_descending(engine: GameEngine):
    engine.register_player("u1", "alice")
    engine.register_player("u2", "bob")
    engine.scores["u1"] = 3
    engine.scores["u2"] = 7
    sb = engine._scoreboard()
    assert [r["nickname"] for r in sb] == ["bob", "alice"]
    assert sb[0]["score"] == 7


def test_scoreboard_includes_offline_players(engine: GameEngine):
    engine.register_player("u1", "alice")
    engine.scores["u1"] = 2
    engine.scores["u2"] = 0  # disconnected user lingering in scores
    sb = engine._scoreboard()
    nicks = {r["nickname"] for r in sb}
    assert "alice" in nicks
    # disconnected user shows the (나감) placeholder & online=False
    ghost = [r for r in sb if r["user_id"] == "u2"][0]
    assert ghost["online"] is False


def test_snapshot_waiting_has_no_current(engine: GameEngine):
    snap = engine.snapshot()
    assert snap["type"] == "room_state"
    assert snap["status"] == "waiting"
    assert snap["current"] is None
    assert snap["win_score"] == 20


@pytest.mark.asyncio
async def test_reset_for_rematch_clears_round_state_and_zeros_scores(engine: GameEngine):
    engine.register_player("u1", "a")
    engine.scores["u1"] = 5
    engine.used_question_ids.add("q1")
    engine.current_round = 7
    engine.first_answerer = "u1"
    engine.skip_votes.add("u1")
    engine.status = "ended"

    ok = await engine.reset_for_rematch()
    assert ok is True
    assert engine.status == "waiting"
    assert engine.scores["u1"] == 0
    assert engine.used_question_ids == set()
    assert engine.current_round == 0
    assert engine.first_answerer is None
    assert engine.skip_votes == set()


@pytest.mark.asyncio
async def test_reset_for_rematch_refused_while_playing(engine: GameEngine):
    engine.status = "playing"
    assert await engine.reset_for_rematch() is False
    assert engine.status == "playing"


class _FakeRedis:
    """Minimal stand-in for redis.asyncio.Redis used by submit_chat and bans."""

    def __init__(self, allow_lock: bool = True) -> None:
        self.allow_lock = allow_lock
        self.calls: list[tuple] = []
        self.sets: dict[str, set[str]] = {}
        self.expirations: dict[str, int] = {}

    async def set(self, key, value, nx=False, ex=None):
        self.calls.append(("set", key, value, nx, ex))
        return self.allow_lock

    async def sadd(self, key, *values):
        self.sets.setdefault(key, set()).update(values)
        return len(values)

    async def sismember(self, key, value):
        return value in self.sets.get(key, set())

    async def expire(self, key, seconds):
        self.expirations[key] = seconds
        return True


def _make_question(answer: str = "서울", accepted: list[str] | None = None) -> Question:
    q = Question(
        prompt="대한민국의 수도는?",
        answer=answer,
        answer_normalized=answer,
        accepted_answers=accepted or [],
        category="지리",
        difficulty=1,
    )
    return q


@pytest.mark.asyncio
async def test_submit_chat_correct_answer_wins(engine: GameEngine, monkeypatch):
    from app.game import engine as engine_module

    fake = _FakeRedis(allow_lock=True)
    monkeypatch.setattr(engine_module, "get_redis", lambda: fake)

    engine.register_player("u1", "alice")
    engine.status = "playing"
    engine.current_round = 1
    engine.current_question = _make_question("서울")

    won = await engine.submit_chat("u1", "서울")
    assert won is True
    assert engine.first_answerer == "u1"
    assert engine._round_event.is_set()


@pytest.mark.asyncio
async def test_submit_chat_wrong_answer_ignored(engine: GameEngine, monkeypatch):
    from app.game import engine as engine_module

    monkeypatch.setattr(engine_module, "get_redis", lambda: _FakeRedis())

    engine.register_player("u1", "alice")
    engine.status = "playing"
    engine.current_round = 1
    engine.current_question = _make_question("서울")

    won = await engine.submit_chat("u1", "부산")
    assert won is False
    assert engine.first_answerer is None
    assert not engine._round_event.is_set()


@pytest.mark.asyncio
async def test_submit_chat_normalization_ignores_spaces(engine: GameEngine, monkeypatch):
    from app.game import engine as engine_module

    monkeypatch.setattr(engine_module, "get_redis", lambda: _FakeRedis())

    engine.register_player("u1", "alice")
    engine.status = "playing"
    engine.current_round = 1
    engine.current_question = _make_question("세종대왕")

    won = await engine.submit_chat("u1", "  세 종 대 왕!  ")
    assert won is True


@pytest.mark.asyncio
async def test_submit_chat_accepted_alternates_match(engine: GameEngine, monkeypatch):
    from app.game import engine as engine_module

    monkeypatch.setattr(engine_module, "get_redis", lambda: _FakeRedis())

    engine.register_player("u1", "alice")
    engine.status = "playing"
    engine.current_round = 1
    engine.current_question = _make_question(
        "H2O", accepted=["에이치투오", "물"]
    )

    assert await engine.submit_chat("u1", "물") is True


@pytest.mark.asyncio
async def test_submit_chat_loses_redis_lock(engine: GameEngine, monkeypatch):
    """Two users submit the right answer concurrently; only the one that
    obtains the Redis lock 'wins'. We simulate by saying the lock denies."""
    from app.game import engine as engine_module

    monkeypatch.setattr(engine_module, "get_redis", lambda: _FakeRedis(allow_lock=False))

    engine.register_player("u1", "alice")
    engine.register_player("u2", "bob")
    engine.status = "playing"
    engine.current_round = 1
    engine.current_question = _make_question("서울")

    won = await engine.submit_chat("u2", "서울")
    assert won is False
    assert engine.first_answerer is None


@pytest.mark.asyncio
async def test_submit_chat_after_someone_already_won_is_noop(
    engine: GameEngine, monkeypatch
):
    from app.game import engine as engine_module

    monkeypatch.setattr(engine_module, "get_redis", lambda: _FakeRedis(allow_lock=True))

    engine.register_player("u1", "alice")
    engine.register_player("u2", "bob")
    engine.status = "playing"
    engine.current_round = 1
    engine.current_question = _make_question("서울")
    engine.first_answerer = "u1"  # someone already won

    won = await engine.submit_chat("u2", "서울")
    assert won is False
    assert engine.first_answerer == "u1"


# ----- bans (kick enforcement) -----------------------------------------------
# Regression cover: a kicked client reconnects on its own backoff about a second
# later. Before bans existed the server happily let it back in, so `kick` was
# purely cosmetic.


@pytest.mark.asyncio
async def test_ban_blocks_rejoin(engine: GameEngine, monkeypatch):
    from app.game import engine as engine_module

    fake = _FakeRedis()
    monkeypatch.setattr(engine_module, "get_redis", lambda: fake)

    await engine.ban("u2")
    assert await engine.is_banned("u2") is True
    assert await engine.is_banned("u1") is False


@pytest.mark.asyncio
async def test_ban_persisted_to_redis_with_ttl(engine: GameEngine, monkeypatch):
    from app.game import engine as engine_module

    fake = _FakeRedis()
    monkeypatch.setattr(engine_module, "get_redis", lambda: fake)

    await engine.ban("u2")
    key = f"room:{engine.room_id}:banned"
    assert fake.sets[key] == {"u2"}
    assert fake.expirations[key] == engine_module.BAN_TTL_SECONDS


@pytest.mark.asyncio
async def test_ban_outlives_recent_kicks(engine: GameEngine, monkeypatch):
    """`recent_kicks` is cleared the moment the socket tears down — that is
    exactly when the kicked client starts reconnecting, so the ban must not be
    tied to it."""
    from app.game import engine as engine_module

    monkeypatch.setattr(engine_module, "get_redis", lambda: _FakeRedis())

    engine.recent_kicks.add("u2")
    await engine.ban("u2")
    engine.recent_kicks.discard("u2")

    assert await engine.is_banned("u2") is True


@pytest.mark.asyncio
async def test_ban_enforced_when_redis_unavailable(engine: GameEngine, monkeypatch):
    from app.game import engine as engine_module

    def _boom():
        raise RuntimeError("Redis not initialized")

    monkeypatch.setattr(engine_module, "get_redis", _boom)

    await engine.ban("u2")  # persistence fails, in-memory set still holds
    assert await engine.is_banned("u2") is True


def test_snapshot_carries_the_hint_once_it_was_revealed(engine: GameEngine):
    """A player who reconnects after the halfway hint must still see it."""
    engine.status = "playing"
    engine.current_round = 2
    engine.current_question = Question(
        prompt="p", answer="1592", answer_normalized="1592", category="역사", difficulty=1
    )
    assert engine.snapshot()["current"]["hint"] is None
    engine.current_hint = "1○○○"
    assert engine.snapshot()["current"]["hint"] == "1○○○"


async def test_rematch_reset_clears_the_hint(engine: GameEngine):
    engine.status = "ended"
    engine.current_hint = "ㅅㅇ"
    assert await engine.reset_for_rematch() is True
    assert engine.current_hint is None
