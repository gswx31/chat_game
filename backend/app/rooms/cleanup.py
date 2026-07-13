"""Idle-room garbage collection.

A background task started by the FastAPI lifespan deletes rooms that have been
idle for ``IDLE_MINUTES`` and are not actively playing. `last_active_at` is
bumped on player connect, on start_game, on rematch, and at every round-end
inside the game engine — so a long active game cannot be wiped mid-play."""

from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete

from app.db.models import Room
from app.db.session import SessionLocal

log = logging.getLogger(__name__)

IDLE_MINUTES = 30
CHECK_INTERVAL_SECONDS = 300  # 5 minutes


async def _sweep_once() -> int:
    cutoff = datetime.now(UTC) - timedelta(minutes=IDLE_MINUTES)
    async with SessionLocal() as db:
        result = await db.execute(
            delete(Room).where(
                Room.last_active_at < cutoff,
                Room.status.in_(["waiting", "ended"]),
            )
        )
        await db.commit()
        return result.rowcount or 0


async def cleanup_idle_rooms() -> None:
    """Run forever until cancelled."""
    while True:
        try:
            await asyncio.sleep(CHECK_INTERVAL_SECONDS)
            removed = await _sweep_once()
            if removed:
                log.info("idle-room cleanup removed %d rooms", removed)
        except asyncio.CancelledError:
            break
        except Exception:  # noqa: BLE001
            log.exception("idle-room cleanup iteration failed")
