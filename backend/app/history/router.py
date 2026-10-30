from datetime import datetime

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import Integer, case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.db.models import GameResult
from app.db.session import get_session
from app.game.results import is_win

router = APIRouter()


class HistoryItem(BaseModel):
    id: int
    played_at: datetime
    room_name: str
    score: int
    rank: int
    player_count: int
    win_score: int
    winner_nickname: str | None
    won: bool


class HistoryResponse(BaseModel):
    games: int
    wins: int
    total_score: int
    items: list[HistoryItem]


@router.get("/me", response_model=HistoryResponse)
async def my_history(
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> HistoryResponse:
    """The caller's finished games, newest first, plus lifetime totals."""
    won = (GameResult.rank == 1) & (GameResult.score > 0) & (GameResult.player_count >= 2)
    games, wins, total = (
        await db.execute(
            select(
                func.count(GameResult.id),
                func.coalesce(func.sum(case((won, 1), else_=0).cast(Integer)), 0),
                func.coalesce(func.sum(GameResult.score), 0),
            ).where(GameResult.user_id == user_id)
        )
    ).one()

    rows = (
        await db.scalars(
            select(GameResult)
            .where(GameResult.user_id == user_id)
            .order_by(GameResult.played_at.desc(), GameResult.id.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return HistoryResponse(
        games=games,
        wins=wins,
        total_score=total,
        items=[
            HistoryItem(
                id=r.id,
                played_at=r.played_at,
                room_name=r.room_name,
                score=r.score,
                rank=r.rank,
                player_count=r.player_count,
                win_score=r.win_score,
                winner_nickname=r.winner_nickname,
                won=is_win(r.rank, r.score, r.player_count),
            )
            for r in rows
        ],
    )
