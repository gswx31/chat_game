from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.db.models import QuestionSet, Room, RoomMember
from app.db.session import get_session
from app.rooms import code as code_util
from app.rooms.presence import live_count
from app.rooms.schemas import RoomCreate, RoomDetail, RoomListItem

router = APIRouter()

_CODE_RETRY = 8


async def _allocate_code(db: AsyncSession) -> str:
    """Pick an unused 6-char code. Retries on rare collisions."""
    for _ in range(_CODE_RETRY):
        candidate = code_util.generate_code()
        exists = await db.scalar(select(Room.id).where(Room.code == candidate))
        if not exists:
            return candidate
    raise HTTPException(500, "Failed to allocate room code; please retry")


@router.get("", response_model=list[RoomListItem])
async def list_rooms(db: AsyncSession = Depends(get_session)) -> list[RoomListItem]:
    """Public rooms that somebody is actually in. A room with nobody in it is a leftover
    (everyone left, or the owner never connected): hidden here at once, and the background
    sweep in ``app/rooms/cleanup.py`` deletes it shortly after."""
    rows = await db.execute(
        select(Room)
        .where(Room.status == "waiting", Room.is_public.is_(True))
        .order_by(Room.created_at.desc())
    )
    return [
        RoomListItem(
            id=r.id,
            code=r.code,
            name=r.name,
            is_public=r.is_public,
            max_players=r.max_players,
            status=r.status,
            win_score=r.win_score,
            created_at=r.created_at,
            player_count=count,
        )
        for r in rows.scalars()
        if (count := live_count(r.id)) > 0
    ]


@router.post("", response_model=RoomDetail, status_code=status.HTTP_201_CREATED)
async def create_room(
    body: RoomCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> RoomDetail:
    if body.difficulty_min > body.difficulty_max:
        raise HTTPException(400, "difficulty_min must be <= difficulty_max")

    # Validate question_set_id if provided
    if body.question_set_id:
        qs = await db.get(QuestionSet, body.question_set_id)
        if not qs:
            raise HTTPException(400, "맵을 찾을 수 없어요")
        if not qs.is_public and qs.creator_id != user_id:
            raise HTTPException(403, "비공개 맵은 본인만 사용할 수 있어요")

    code = await _allocate_code(db)
    room = Room(
        code=code,
        name=body.name,
        is_public=body.is_public,
        owner_id=user_id,
        max_players=body.max_players,
        win_score=body.win_score,
        round_seconds=body.round_seconds,
        categories=body.categories,
        difficulty_min=body.difficulty_min,
        difficulty_max=body.difficulty_max,
        question_set_id=body.question_set_id,
    )
    db.add(room)
    await db.flush()
    db.add(RoomMember(room_id=room.id, user_id=user_id))
    await db.commit()
    await db.refresh(room)
    return _to_detail(room, player_count=1)


@router.get("/by-code/{code}", response_model=RoomDetail)
async def get_room_by_code(
    code: str, db: AsyncSession = Depends(get_session)
) -> RoomDetail:
    code = code_util.normalize(code)
    if not code_util.is_well_formed(code):
        raise HTTPException(400, "Invalid room code")
    room = await db.scalar(select(Room).where(Room.code == code))
    if not room:
        raise HTTPException(404, "Room not found")
    return _to_detail(room, player_count=live_count(room.id))


@router.get("/{room_id}", response_model=RoomDetail)
async def get_room(room_id: str, db: AsyncSession = Depends(get_session)) -> RoomDetail:
    room = await db.get(Room, room_id)
    if not room:
        raise HTTPException(404, "Room not found")
    return _to_detail(room, player_count=live_count(room_id))


def _to_detail(room: Room, player_count: int) -> RoomDetail:
    return RoomDetail(
        id=room.id,
        code=room.code,
        name=room.name,
        is_public=room.is_public,
        owner_id=room.owner_id,
        max_players=room.max_players,
        status=room.status,
        win_score=room.win_score,
        round_seconds=room.round_seconds,
        categories=room.categories,
        difficulty_min=room.difficulty_min,
        difficulty_max=room.difficulty_max,
        question_set_id=room.question_set_id,
        created_at=room.created_at,
        player_count=player_count,
    )
