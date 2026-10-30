"""Engine lifecycle + live occupancy.

Both cover bugs that were invisible in normal play but compounded over time:
engines were never released from the process, and "how many people are in this
room" was answered by counting join-history rows."""

from __future__ import annotations

import asyncio
from typing import Any

import pytest

from app.game import registry
from app.game.engine import RoomConfig


async def _noop_broadcast(_room_id: str, _msg: dict[str, Any]) -> None:
    return None


def _cfg() -> RoomConfig:
    return RoomConfig(
        win_score=20,
        round_seconds=30,
        categories=[],
        difficulty_min=1,
        difficulty_max=5,
        owner_id="u1",
    )


@pytest.fixture(autouse=True)
def _clean_registry():
    registry._engines.clear()
    yield
    registry._engines.clear()


@pytest.mark.asyncio
async def test_drop_releases_abandoned_waiting_room():
    """The old condition required status == 'ended', so a room everyone left
    while still in the lobby stayed resident for the life of the process."""
    eng = await registry.get_or_create("r1", _cfg, _noop_broadcast)
    eng.register_player("u1", "alice")
    eng.unregister_player("u1")

    assert eng.status == "waiting"
    await registry.drop_if_empty("r1")
    assert registry.get("r1") is None


@pytest.mark.asyncio
async def test_drop_keeps_engine_while_players_present():
    eng = await registry.get_or_create("r2", _cfg, _noop_broadcast)
    eng.register_player("u1", "alice")

    await registry.drop_if_empty("r2")
    assert registry.get("r2") is eng


@pytest.mark.asyncio
async def test_drop_defers_until_game_loop_finishes():
    """Dropping mid-loop would let a reconnect build a second engine while the
    first was still broadcasting into the same room id."""
    eng = await registry.get_or_create("r3", _cfg, _noop_broadcast)
    started, release = asyncio.Event(), asyncio.Event()

    async def _fake_loop() -> None:
        started.set()
        await release.wait()

    eng.status = "playing"
    eng.task = asyncio.create_task(_fake_loop())
    await started.wait()

    # Nobody left in the room, but the loop is still winding down.
    await registry.drop_if_empty("r3")
    assert registry.get("r3") is eng

    release.set()
    await eng.task
    eng.task = None  # the real _run clears this in its finally block
    await registry.drop_if_empty("r3")
    assert registry.get("r3") is None


@pytest.mark.asyncio
async def test_live_count_tracks_occupancy_not_join_history():
    from app.rooms.presence import live_count as _live_count

    eng = await registry.get_or_create("r4", _cfg, _noop_broadcast)
    eng.register_player("u1", "alice")
    eng.register_player("u2", "bob")
    assert _live_count("r4") == 2

    eng.unregister_player("u1")
    # alice left: occupancy drops, but her score ledger entry stays behind —
    # counting those rows is what used to wedge rooms shut at max_players.
    assert _live_count("r4") == 1
    assert "u1" in eng.scores


@pytest.mark.asyncio
async def test_live_count_zero_for_unknown_room():
    from app.rooms.presence import live_count as _live_count

    assert _live_count("nope") == 0
