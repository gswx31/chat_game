"""Who is in a room *right now*.

Counting ``RoomMember`` rows instead reported everyone who had ever joined, so the lobby
showed "28/30" for a room holding two people and eventually refused entry to an empty room.
Same single-worker assumption as the rest of the realtime layer (see ``app/ws/manager.py``).
"""

from __future__ import annotations

from app.game import registry
from app.ws.manager import manager


def live_count(room_id: str) -> int:
    """People present, including the ones inside the 20 s reconnect grace window."""
    eng = registry.get(room_id)
    if eng is not None:
        return len(eng.players)
    return manager.count(room_id)


def engine_running(room_id: str) -> bool:
    """True while the room's game loop is still winding down (it removes itself afterwards)."""
    eng = registry.get(room_id)
    return eng is not None and eng.task is not None and not eng.task.done()
