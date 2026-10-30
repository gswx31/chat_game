"""Room garbage collection.

A background task started by the FastAPI lifespan deletes

* rooms nobody is in: a room that has been empty for ``EMPTY_GRACE_SECONDS`` is a leftover
  (everyone left, the owner never connected, or the server restarted mid-game). The grace
  period covers someone dropping out and coming straight back, and the gap between creating
  a room and opening its socket. The lobby list already hides empty rooms at once;
* rooms idle for ``IDLE_MINUTES`` that are not playing. `last_active_at` is bumped on player
  connect, on start_game, on rematch, and at every round-end inside the game engine -- so a
  long active game cannot be wiped mid-play.

Game results live in ``game_results``, independent of rooms, so deleting a room loses no history.
"""

from __future__ import annotations

import asyncio
import logging
import time
from collections.abc import Callable, Iterable
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select

from app.db.models import Room
from app.db.session import SessionLocal
from app.rooms.presence import engine_running, live_count

log = logging.getLogger(__name__)

IDLE_MINUTES = 30
CHECK_INTERVAL_SECONDS = 15
EMPTY_GRACE_SECONDS = 45

# room id -> monotonic time we first saw it empty
_empty_since: dict[str, float] = {}


def find_abandoned(
    room_ids: Iterable[str],
    live: Callable[[str], int],
    running: Callable[[str], bool],
    empty_since: dict[str, float],
    now: float,
    grace: float = EMPTY_GRACE_SECONDS,
) -> list[str]:
    """Rooms that have had nobody in them for at least ``grace`` seconds.

    ``empty_since`` is the memory between sweeps (updated in place): a room is added the first
    time it is seen empty and forgotten as soon as somebody is back or the room is gone.
    """
    ids = list(room_ids)
    present = set(ids)
    for rid in [r for r in empty_since if r not in present]:
        del empty_since[rid]
    abandoned: list[str] = []
    for rid in ids:
        if live(rid) > 0 or running(rid):
            empty_since.pop(rid, None)
            continue
        first = empty_since.setdefault(rid, now)
        if now - first >= grace:
            abandoned.append(rid)
    return abandoned


async def _sweep_once() -> int:
    cutoff = datetime.now(UTC) - timedelta(minutes=IDLE_MINUTES)
    async with SessionLocal() as db:
        result = await db.execute(
            delete(Room).where(
                Room.last_active_at < cutoff,
                Room.status.in_(["waiting", "ended"]),
            )
        )
        removed = result.rowcount or 0

        ids = (await db.scalars(select(Room.id))).all()
        abandoned = find_abandoned(ids, live_count, engine_running, _empty_since, time.monotonic())
        # one last look right before deleting: somebody may have just walked in
        abandoned = [r for r in abandoned if live_count(r) == 0 and not engine_running(r)]
        if abandoned:
            result = await db.execute(delete(Room).where(Room.id.in_(abandoned)))
            removed += result.rowcount or 0
            for rid in abandoned:
                _empty_since.pop(rid, None)
        await db.commit()
        return removed


async def cleanup_idle_rooms() -> None:
    """Run forever until cancelled."""
    while True:
        try:
            await asyncio.sleep(CHECK_INTERVAL_SECONDS)
            removed = await _sweep_once()
            if removed:
                log.info("room cleanup removed %d rooms", removed)
        except asyncio.CancelledError:
            break
        except Exception:  # noqa: BLE001
            log.exception("room cleanup iteration failed")
