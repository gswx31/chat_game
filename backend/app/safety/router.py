"""Report and block other players (Google Play UGC policy: in-app report + block).

``POST /safety/reports``        report a player (the operator reviews with scripts/moderation.py)
``GET  /safety/blocks``         who I have blocked
``PUT  /safety/blocks/{id}``    block a player: their chat lines stop reaching me
``DELETE /safety/blocks/{id}``  unblock
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from enum import StrEnum

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.db.models import Report, User, UserBlock
from app.db.session import get_session
from app.safety.blocks import blocks

router = APIRouter()

MAX_REPORTS_PER_DAY = 20
DUPLICATE_WINDOW = timedelta(hours=1)
MAX_BLOCKS = 200


class ReportReason(StrEnum):
    ABUSE = "abuse"  # 욕설·비하·괴롭힘
    SEXUAL = "sexual"  # 음란·선정적인 내용
    SPAM = "spam"  # 도배·광고
    CHEAT = "cheat"  # 정답 유출·부정행위
    OTHER = "other"


class ReportRequest(BaseModel):
    target_user_id: str = Field(min_length=1, max_length=32)
    reason: ReportReason
    detail: str | None = Field(default=None, max_length=300)
    # The chat line being reported, as the reporter saw it.
    message_text: str | None = Field(default=None, max_length=300)
    room_code: str | None = Field(default=None, max_length=6)


class ReportResponse(BaseModel):
    ok: bool = True
    # True when this reporter already filed the same report (same player, reason and chat line)
    # within the last hour: nothing new is recorded, the client still says "접수됐어요".
    duplicate: bool = False


class BlockedUser(BaseModel):
    user_id: str
    nickname: str
    blocked_at: datetime


class OkResponse(BaseModel):
    ok: bool = True


def _clean(text: str | None) -> str | None:
    text = (text or "").strip()
    return text or None


@router.post("/reports", response_model=ReportResponse)
async def report_user(
    body: ReportRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> ReportResponse:
    if body.target_user_id == user_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "본인은 신고할 수 없어요")
    target = await db.get(User, body.target_user_id)
    if not target:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "신고할 사용자를 찾을 수 없어요")

    now = datetime.now(UTC)
    message_text = _clean(body.message_text)
    recent = (
        await db.execute(
            select(Report.target_id, Report.reason, Report.message_text, Report.created_at).where(
                Report.reporter_id == user_id, Report.created_at >= now - timedelta(days=1)
            )
        )
    ).all()
    # Tapping "신고" twice must not file twice, but a different reason or a new offending line
    # about the same player is new information and is kept.
    cutoff = now - DUPLICATE_WINDOW
    if any(
        (t, rs, msg) == (body.target_user_id, body.reason.value, message_text) and at >= cutoff
        for t, rs, msg, at in recent
    ):
        return ReportResponse(duplicate=True)
    if len(recent) >= MAX_REPORTS_PER_DAY:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "오늘은 더 신고할 수 없어요")

    db.add(
        Report(
            reporter_id=user_id,
            target_id=target.id,
            target_nickname=target.nickname,
            reason=body.reason.value,
            detail=_clean(body.detail),
            message_text=message_text,
            room_code=_clean(body.room_code),
        )
    )
    await db.commit()
    return ReportResponse()


@router.get("/blocks", response_model=list[BlockedUser])
async def my_blocks(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> list[BlockedUser]:
    rows = (
        await db.execute(
            select(UserBlock.blocked_id, User.nickname, UserBlock.created_at)
            .join(User, User.id == UserBlock.blocked_id)
            .where(UserBlock.blocker_id == user_id)
            .order_by(UserBlock.created_at.desc())
        )
    ).all()
    return [BlockedUser(user_id=r[0], nickname=r[1], blocked_at=r[2]) for r in rows]


@router.put("/blocks/{target_id}", response_model=OkResponse)
async def block_user(
    target_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> OkResponse:
    if target_id == user_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "본인은 차단할 수 없어요")
    if not await db.get(User, target_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "차단할 사용자를 찾을 수 없어요")
    count = await db.scalar(
        select(func.count(UserBlock.id)).where(UserBlock.blocker_id == user_id)
    )
    if (count or 0) >= MAX_BLOCKS:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "차단 목록이 가득 찼어요")
    await db.execute(
        pg_insert(UserBlock)
        .values(blocker_id=user_id, blocked_id=target_id)
        .on_conflict_do_nothing(constraint="uq_user_block")
    )
    await db.commit()
    blocks.add(user_id, target_id)
    return OkResponse()


@router.delete("/blocks/{target_id}", response_model=OkResponse)
async def unblock_user(
    target_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> OkResponse:
    row = await db.scalar(
        select(UserBlock).where(UserBlock.blocker_id == user_id, UserBlock.blocked_id == target_id)
    )
    if row:
        await db.delete(row)
        await db.commit()
    blocks.discard(user_id, target_id)
    return OkResponse()
