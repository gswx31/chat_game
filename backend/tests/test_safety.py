from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from app.safety.blocks import BlockCache
from app.safety.router import ReportReason, ReportRequest
from app.safety.suspension import is_suspended
from app.ws.manager import RoomManager


class FakeSocket:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    async def accept(self) -> None:
        pass

    async def send_json(self, message: dict) -> None:
        self.sent.append(message)


def test_block_cache_answers_per_recipient():
    cache = BlockCache()
    cache.set("alice", ["troll"])
    assert cache.blocks("alice", "troll")
    assert not cache.blocks("alice", "bob")
    assert not cache.blocks("bob", "troll")  # blocking is one-directional


def test_block_cache_ignores_updates_for_users_that_are_not_loaded():
    cache = BlockCache()
    cache.add("alice", "troll")  # alice not loaded: a partial set must not pose as the full one
    assert cache.get("alice") == frozenset()
    cache.set("alice", [])
    cache.add("alice", "troll")
    assert cache.blocks("alice", "troll")
    cache.discard("alice", "troll")
    assert not cache.blocks("alice", "troll")


@pytest.mark.asyncio
async def test_broadcast_skips_recipients_who_blocked_the_sender():
    manager = RoomManager()
    sockets = {u: FakeSocket() for u in ("alice", "bob", "troll")}
    for user_id, ws in sockets.items():
        await manager.connect("room", user_id, ws)  # type: ignore[arg-type]
    cache = BlockCache()
    cache.set("alice", ["troll"])

    await manager.broadcast(
        "room",
        {"type": "chat", "user_id": "troll", "text": "..."},
        skip_if=lambda recipient: cache.blocks(recipient, "troll"),
    )

    assert sockets["alice"].sent == []
    assert len(sockets["bob"].sent) == 1
    assert len(sockets["troll"].sent) == 1  # the sender still sees their own line


@pytest.mark.asyncio
async def test_broadcast_without_a_filter_reaches_everyone():
    manager = RoomManager()
    a, b = FakeSocket(), FakeSocket()
    await manager.connect("room", "a", a)  # type: ignore[arg-type]
    await manager.connect("room", "b", b)  # type: ignore[arg-type]
    await manager.broadcast("room", {"type": "player_join"})
    assert len(a.sent) == len(b.sent) == 1


def test_suspension_lasts_until_the_deadline():
    now = datetime.now(UTC)
    ok = SimpleNamespace(suspended_until=None)
    active = SimpleNamespace(suspended_until=now + timedelta(days=1))
    over = SimpleNamespace(suspended_until=now - timedelta(seconds=1))
    assert not is_suspended(ok)  # type: ignore[arg-type]
    assert is_suspended(active)  # type: ignore[arg-type]
    assert not is_suspended(over)  # type: ignore[arg-type]
    assert not is_suspended(None)


def test_report_needs_a_known_reason_and_bounded_text():
    ReportRequest(target_user_id="u1", reason=ReportReason.ABUSE, message_text="x" * 300)
    with pytest.raises(ValidationError):
        ReportRequest(target_user_id="u1", reason="whatever")  # type: ignore[arg-type]
    with pytest.raises(ValidationError):
        ReportRequest(target_user_id="u1", reason=ReportReason.SPAM, detail="x" * 301)
    with pytest.raises(ValidationError):
        ReportRequest(target_user_id="", reason=ReportReason.SPAM)
