from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.models import Question
from app.db.session import get_session
from app.questions.seed_data import CATEGORIES
from app.questions.sync import sync_questions

router = APIRouter()


@router.get("/categories")
async def categories() -> list[str]:
    return CATEGORIES


@router.get("/count")
async def count(db: AsyncSession = Depends(get_session)) -> dict[str, int]:
    n = await db.scalar(select(func.count(Question.id)))
    return {"count": n or 0}


@router.post("/seed", status_code=201)
async def seed(db: AsyncSession = Depends(get_session)) -> dict[str, int]:
    """Dev convenience: make the table match ``seed_data.py``. Closed in production
    (deploys run ``scripts.sync_questions`` instead)."""
    if settings.app_env == "production":
        raise HTTPException(status_code=404)
    plan = await sync_questions(db)
    await db.commit()
    return {"inserted": len(plan.insert), "updated": len(plan.update), "deleted": len(plan.delete)}
