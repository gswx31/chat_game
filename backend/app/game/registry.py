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
    async with _lock:
        eng = _engines.get(room_id)
        if eng and not eng.has_players and eng.status == "ended":
            _engines.pop(room_id, None)
