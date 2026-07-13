"""Unit tests for GameEngine. The async game loop (_run) and DB picking are
not exercised here — those need an integration setup. We cover the pure-logic
parts: presence, scoreboard, snapshot, rematch reset, and submit_chat with a
fake Redis."""

from __future__ import annotations

from typing import Any

import pytest

from app.db.models import Question
from app.game.engine import GameEngine, RoomConfig


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


def test_skip_threshold_grows_with_players(engine: GameEngine):
    assert engine._skip_threshold() == 1  # empty: floor 1
    engine.register_player("u1", "a")
    engine.register_player("u2", "b")
    assert engine._skip_threshold() >= 1
    engine.register_player("u3", "c")
    engine.register_player("u4", "d")
    # 4 players → (4+1)//2 = 2
    assert engine._skip_threshold() == 2


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
    """Minimal stand-in for redis.asyncio.Redis used by submit_chat."""

    def __init__(self, allow_lock: bool = True) -> None:
        self.allow_lock = allow_lock
        self.calls: list[tuple] = []

    async def set(self, key, value, nx=False, ex=None):
        self.calls.append(("set", key, value, nx, ex))
        return self.allow_lock


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
