"""Who has blocked whom, kept in memory for the chat fan-out.

The WebSocket handler asks "does recipient R block sender S?" once per recipient per chat
line, so the answer must not cost a query. A user's set is loaded when they join a room and
kept in step by the block / unblock endpoints. Single-process, like ``RoomManager``.
"""

from __future__ import annotations

from collections.abc import Iterable

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import UserBlock

_EMPTY: frozenset[str] = frozenset()


class BlockCache:
    def __init__(self) -> None:
        self._by_user: dict[str, frozenset[str]] = {}

    def get(self, user_id: str) -> frozenset[str]:
        return self._by_user.get(user_id, _EMPTY)

    def blocks(self, recipient_id: str, sender_id: str) -> bool:
        return sender_id in self._by_user.get(recipient_id, _EMPTY)

    def set(self, user_id: str, blocked: Iterable[str]) -> None:
        self._by_user[user_id] = frozenset(blocked)

    # Only touch users whose set is loaded: a partial set must never pass for the full one,
    # and an unloaded user is read from the database when they next join a room.
    def add(self, user_id: str, blocked_id: str) -> None:
        if user_id in self._by_user:
            self._by_user[user_id] = self._by_user[user_id] | {blocked_id}

    def discard(self, user_id: str, blocked_id: str) -> None:
        if user_id in self._by_user:
            self._by_user[user_id] = self._by_user[user_id] - {blocked_id}

    async def load(self, db: AsyncSession, user_id: str) -> None:
        rows = await db.scalars(select(UserBlock.blocked_id).where(UserBlock.blocker_id == user_id))
        self.set(user_id, rows.all())


blocks = BlockCache()
