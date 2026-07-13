from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Question
from app.db.session import get_session
from app.questions.normalize import normalize_answer
from app.questions.seed_data import CATEGORIES, SEED

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
    """Dev convenience: insert seed questions if table is empty."""
    existing = await db.scalar(select(func.count(Question.id)))
    if existing:
        return {"inserted": 0, "existing": existing}
    inserted = 0
    for item in SEED:
        q = Question(
            prompt=item["prompt"],
            answer=item["answer"],
            answer_normalized=normalize_answer(item["answer"]),
            accepted_answers=[normalize_answer(a) for a in item.get("accepted", [])],
            category=item["category"],
            difficulty=item.get("difficulty", 2),
            hint=item.get("hint"),
        )
        db.add(q)
        inserted += 1
    await db.commit()
    return {"inserted": inserted, "existing": 0}
