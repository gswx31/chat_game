from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.schemas import (
    GuestLoginRequest,
    MeResponse,
    ProfileUpdateRequest,
    TokenResponse,
)
from app.core.security import create_access_token, get_current_user_id
from app.db.models import User
from app.db.session import get_session
from app.safety.suspension import is_suspended

router = APIRouter()


def _to_token(user: User) -> TokenResponse:
    token = create_access_token(subject=user.id, extra={"nickname": user.nickname})
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        nickname=user.nickname,
    )


def _to_me(user: User) -> MeResponse:
    return MeResponse(
        user_id=user.id,
        nickname=user.nickname,
        photo_url=user.photo_url,
        email=user.email,
        is_guest=user.is_guest,
    )


@router.post("/guest", response_model=TokenResponse)
async def guest_login(
    body: GuestLoginRequest,
    db: AsyncSession = Depends(get_session),
) -> TokenResponse:
    """device_id로 게스트 계정 find-or-create.
    같은 기기에서 항상 같은 user_id를 반환한다.
    firebase_uid 컬럼을 device_id 저장소로 재사용."""
    user = await db.scalar(
        select(User).where(User.firebase_uid == body.device_id)
    )
    if not user:
        nickname = f"Guest_{body.device_id[:8]}"
        user = User(
            firebase_uid=body.device_id,
            nickname=nickname,
            is_guest=True,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
    if is_suspended(user):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "이용이 제한된 계정이에요")
    return _to_token(user)


@router.get("/me", response_model=MeResponse)
async def me(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> MeResponse:
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
    return _to_me(user)


@router.patch("/me", response_model=TokenResponse)
async def update_me(
    body: ProfileUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> TokenResponse:
    """닉네임 변경 후 새 JWT 발급 — WS 세션에 즉시 반영된다."""
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
    if body.nickname is not None:
        n = body.nickname.strip()
        if n:
            user.nickname = n
    if body.photo_url is not None:
        user.photo_url = body.photo_url
    await db.commit()
    await db.refresh(user)
    return _to_token(user)
