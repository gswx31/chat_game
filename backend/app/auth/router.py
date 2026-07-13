from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.schemas import (
    GuestLoginRequest,
    MeResponse,
    ProfileUpdateRequest,
    TokenResponse,
    UpsertRequest,
)
from app.core.security import create_access_token, get_current_user_id
from app.db.models import User
from app.db.session import get_session

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


@router.post("/upsert", response_model=TokenResponse)
async def upsert_user(
    body: UpsertRequest,
    db: AsyncSession = Depends(get_session),
) -> TokenResponse:
    """Find-or-create a User by firebase_uid.
    Guaranteed to return the same user_id for the same Firebase account
    across every app launch, fixing the session-ID drift bug."""
    user = await db.scalar(
        select(User).where(User.firebase_uid == body.firebase_uid)
    )
    if user:
        # Sync any changed profile fields from Firebase
        user.nickname = body.nickname.strip() or user.nickname
        if body.email is not None:
            user.email = body.email
        if body.photo_url is not None:
            user.photo_url = body.photo_url
    else:
        user = User(
            firebase_uid=body.firebase_uid,
            nickname=body.nickname.strip() or "Guest",
            email=body.email,
            photo_url=body.photo_url,
            is_guest=body.is_guest,
        )
        db.add(user)
    await db.commit()
    await db.refresh(user)
    return _to_token(user)


@router.post("/guest", response_model=TokenResponse)
async def guest_login(
    body: GuestLoginRequest,
    db: AsyncSession = Depends(get_session),
) -> TokenResponse:
    """Legacy: throwaway guest row with no firebase_uid. Kept for compatibility."""
    nickname = body.nickname.strip()
    if not nickname:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Nickname required")
    user = User(nickname=nickname, is_guest=True)
    db.add(user)
    await db.commit()
    await db.refresh(user)
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
    """Update nickname / photo_url. Returns a fresh JWT so the new nickname
    is reflected in WebSocket sessions immediately."""
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
