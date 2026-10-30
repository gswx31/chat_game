"""Per-room engine registry. Single-worker only."""

from __future__ import annotations

import asyncio
from typing import Awaitable, Callable

from app.game.engine import GameEngine, RoomConfig

_engines: dict[str, GameEngine] = {}
_lock = asyncio.Lock()


async def get_or_create(
    room_id: str,
    cfg_factory: Callable[[], RoomConfig],
    broadcast: Callable[[str, dict], Awaitable[None]],
) -> GameEngine:
    async with _lock:
        eng = _engines.get(room_id)
        if eng is None:
            eng = GameEngine(room_id, cfg_factory(), broadcast)
            _engines[room_id] = eng
        return eng


def get(room_id: str) -> GameEngine | None:
    return _engines.get(room_id)


async def drop_if_empty(room_id: str) -> None:
    """Release the in-memory engine once the room is empty.

    This used to also require ``status == "ended"``, which leaked an engine for
    every room that was abandoned while still ``waiting`` — and for played-out
    rooms too, since the last player's disconnect runs while the engine is still
    ``playing`` (held by the 20 s grace window). Engines accumulated for the
    lifetime of the process. The engine's own ``finally`` calls back here once
    its loop is done, which covers the case where the room empties mid-game.
    """
    async with _lock:
        eng = _engines.get(room_id)
        if eng is None or eng.has_players:
            return
        if eng.task is not None and not eng.task.done():
            # Game loop is still winding down; it drops itself when it finishes.
            return
        _engines.pop(room_id, None)
