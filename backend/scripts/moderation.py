"""Review player reports and act on them (run on the server, e.g. inside the backend container).

    python -m scripts.moderation list [--all]           open reports, grouped by reported player
    python -m scripts.moderation suspend USER_ID DAYS   suspend; their open reports -> actioned
    python -m scripts.moderation unsuspend USER_ID
    python -m scripts.moderation dismiss REPORT_ID...   close reports without acting

A suspended player cannot log in again or join any room (an open socket is closed at the next
connect). Reports are the reporter's word; the chat line they attach is what their client
showed them, so read it as a pointer, not proof.
"""

from __future__ import annotations

import asyncio
import sys
from datetime import UTC, datetime, timedelta

from sqlalchemy import select, update

from app.db.models import Report, User
from app.db.session import SessionLocal, close_engine

REASON_LABEL = {
    "abuse": "욕설·비하",
    "sexual": "음란·선정",
    "spam": "도배·광고",
    "cheat": "정답 유출·부정",
    "other": "기타",
}


async def _list(show_all: bool) -> int:
    async with SessionLocal() as db:
        q = select(Report).order_by(Report.target_id, Report.created_at)
        if not show_all:
            q = q.where(Report.status == "open")
        reports = (await db.scalars(q)).all()
        names = {
            u.id: u
            for u in (
                await db.scalars(
                    select(User).where(User.id.in_({r.reporter_id for r in reports}))
                )
            ).all()
        }
        targets = {
            u.id: u
            for u in (
                await db.scalars(select(User).where(User.id.in_({r.target_id for r in reports})))
            ).all()
        }
    if not reports:
        print("신고 없음")
        return 0
    last = None
    for r in reports:
        if r.target_id != last:
            last = r.target_id
            t = targets.get(r.target_id)
            n = sum(1 for x in reports if x.target_id == r.target_id)
            until = ""
            if t and t.suspended_until:
                until = f"  [정지 ~{t.suspended_until:%Y-%m-%d %H:%M}]"
            print(f"\n== {r.target_nickname} ({r.target_id}) 신고 {n}건{until}")
        who = names.get(r.reporter_id)
        print(
            f"  #{r.id} {r.created_at:%m-%d %H:%M} [{r.status}] "
            f"{REASON_LABEL.get(r.reason, r.reason)} by {who.nickname if who else '?'}"
            + (f" (방 {r.room_code})" if r.room_code else "")
        )
        if r.message_text:
            print(f"      메시지: {r.message_text}")
        if r.detail:
            print(f"      설명:   {r.detail}")
    return 0


async def _suspend(user_id: str, days: int) -> int:
    async with SessionLocal() as db:
        user = await db.get(User, user_id)
        if not user:
            print("그런 사용자가 없어요")
            return 1
        now = datetime.now(UTC)
        user.suspended_until = now + timedelta(days=days)
        done = await db.execute(
            update(Report)
            .where(Report.target_id == user_id, Report.status == "open")
            .values(status="actioned", resolved_at=now)
        )
        await db.commit()
    print(f"{user.nickname} 정지 {days}일, 처리한 신고 {done.rowcount}건")
    return 0


async def _unsuspend(user_id: str) -> int:
    async with SessionLocal() as db:
        user = await db.get(User, user_id)
        if not user:
            print("그런 사용자가 없어요")
            return 1
        user.suspended_until = None
        await db.commit()
    print(f"{user.nickname} 정지 해제")
    return 0


async def _dismiss(ids: list[int]) -> int:
    async with SessionLocal() as db:
        done = await db.execute(
            update(Report)
            .where(Report.id.in_(ids), Report.status == "open")
            .values(status="dismissed", resolved_at=datetime.now(UTC))
        )
        await db.commit()
    print(f"기각 {done.rowcount}건")
    return 0


async def _amain(argv: list[str]) -> int:
    try:
        match argv:
            case ["list", *rest]:
                return await _list("--all" in rest)
            case ["suspend", user_id, days] if days.isdigit() and int(days) > 0:
                return await _suspend(user_id, int(days))
            case ["unsuspend", user_id]:
                return await _unsuspend(user_id)
            case ["dismiss", *ids] if ids and all(i.isdigit() for i in ids):
                return await _dismiss([int(i) for i in ids])
            case _:
                print(__doc__)
                return 2
    finally:
        await close_engine()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_amain(sys.argv[1:])))
