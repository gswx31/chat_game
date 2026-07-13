"""In-process room connection manager. Single-worker only.

Multi-worker support: replace `broadcast` with Redis pub/sub:
- each worker subscribes to `room:{id}:bus`
- broadcast() publishes to that channel
- subscriber callback fans out to local sockets in self._rooms"""

from __future__ import annotations

import asyncio
from collections import defaultdict
from typing import Any

from fastapi import WebSocket


class RoomManager:
    def __init__(self) -> None:
        self._rooms: dict[str, dict[str, WebSocket]] = defaultdict(dict)
        self._lock = asyncio.Lock()

    async def connect(self, room_id: str, user_id: str, ws: WebSocket) -> None:
        await ws.accept()
        async with self._lock:
            self._rooms[room_id][user_id] = ws

    async def disconnect(self, room_id: str, user_id: str) -> None:
        async with self._lock:
            self._rooms.get(room_id, {}).pop(user_id, None)
            if not self._rooms.get(room_id):
                self._rooms.pop(room_id, None)

    async def broadcast(self, room_id: str, message: dict[str, Any]) -> None:
        sockets = list(self._rooms.get(room_id, {}).values())
        for ws in sockets:
            try:
                await ws.send_json(message)
            except Exception:
                pass

    def has(self, room_id: str, user_id: str) -> bool:
        return user_id in self._rooms.get(room_id, {})

    def count(self, room_id: str) -> int:
        return len(self._rooms.get(room_id, {}))

    async def close_one(
        self, room_id: str, user_id: str, code: int, reason: str = ""
    ) -> None:
        """Forcefully close a single user's socket. The handler's finally block
        will then run disconnect/cleanup as usual."""
        ws = self._rooms.get(room_id, {}).get(user_id)
        if ws is None:
            return
        try:
            await ws.close(code=code, reason=reason)
        except Exception:
            pass


manager = RoomManager()
