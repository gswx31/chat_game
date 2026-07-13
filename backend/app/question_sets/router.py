"""Question set (맵) API.

Public flow:
  POST  /question-sets            — create set (with initial questions)
  GET   /question-sets/my         — my sets (all, incl. private)
  GET   /question-sets/browse     — public sets: search + theme filter + pagination
  GET   /question-sets/popular    — top 20 by play_count
  GET   /question-sets/themes     — available theme list
  GET   /question-sets/by-code/{code}   — full detail by share code (download)
  GET   /question-sets/{id}       — full detail by id (owner only for private)
  PUT   /question-sets/{id}       — update metadata (owner only)
  DELETE /question-sets/{id}      — delete (owner only)

  POST   /question-sets/{id}/questions           — add question
  PUT    /question-sets/{id}/questions/{qid}     — update question
  DELETE /question-sets/{id}/questions/{qid}     — delete question
  POST   /question-sets/{id}/reorder             — bulk reorder questions
"""
from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import get_current_user_id
from app.db.models import QuestionSet, QuestionSetItem, User
from app.db.session import get_session
from app.question_sets import code as code_util
from app.question_sets.schemas import (
    QuestionItemCreate,
    QuestionItemOut,
    QuestionItemUpdate,
    QuestionSetBrief,
    QuestionSetCreate,
    QuestionSetOut,
    QuestionSetUpdate,
    THEMES,
)
from app.questions.normalize import normalize_answer

router = APIRouter()
_CODE_RETRY = 8


async def _allocate_code(db: AsyncSession) -> str:
    for _ in range(_CODE_RETRY):
        candidate = code_util.generate_code()
        exists = await db.scalar(select(QuestionSet.id).where(QuestionSet.code == candidate))
        if not exists:
            return candidate
    raise HTTPException(500, "코드 생성에 실패했습니다. 다시 시도해주세요")


def _item_to_out(item: QuestionSetItem) -> QuestionItemOut:
    return QuestionItemOut(
        id=item.id,
        set_id=item.set_id,
        prompt=item.prompt,
        answer=item.answer,
        accepted_answers=item.accepted_answers or [],
        category=item.category,
        difficulty=item.difficulty,
        hint=item.hint,
        order=item.order,
    )


def _set_to_brief(qs: QuestionSet, item_count: int, creator_nickname: str) -> QuestionSetBrief:
    return QuestionSetBrief(
        id=qs.id,
        code=qs.code,
        name=qs.name,
        description=qs.description,
        creator_id=qs.creator_id,
        creator_nickname=creator_nickname,
        is_public=qs.is_public,
        tags=qs.tags or [],
        play_count=qs.play_count,
        item_count=item_count,
        created_at=qs.created_at,
        updated_at=qs.updated_at,
    )


def _set_to_out(qs: QuestionSet, creator_nickname: str) -> QuestionSetOut:
    items = [_item_to_out(i) for i in (qs.items or [])]
    return QuestionSetOut(
        id=qs.id,
        code=qs.code,
        name=qs.name,
        description=qs.description,
        creator_id=qs.creator_id,
        creator_nickname=creator_nickname,
        is_public=qs.is_public,
        tags=qs.tags or [],
        play_count=qs.play_count,
        item_count=len(items),
        created_at=qs.created_at,
        updated_at=qs.updated_at,
        items=items,
    )


# ── 메타 ──────────────────────────────────────────────────────────────


@router.get("/themes")
async def list_themes() -> list[str]:
    return THEMES


# ── 생성 ──────────────────────────────────────────────────────────────


@router.post("", response_model=QuestionSetOut, status_code=status.HTTP_201_CREATED)
async def create_question_set(
    body: QuestionSetCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> QuestionSetOut:
    code = await _allocate_code(db)
    qs = QuestionSet(
        code=code,
        name=body.name,
        description=body.description,
        creator_id=user_id,
        is_public=body.is_public,
        tags=body.tags,
    )
    db.add(qs)
    await db.flush()

    for idx, item_data in enumerate(body.items):
        db.add(
            QuestionSetItem(
                set_id=qs.id,
                prompt=item_data.prompt,
                answer=item_data.answer,
                answer_normalized=normalize_answer(item_data.answer),
                accepted_answers=[normalize_answer(a) for a in item_data.accepted_answers],
                category=item_data.category,
                difficulty=item_data.difficulty,
                hint=item_data.hint,
                order=idx,
            )
        )

    await db.commit()
    await db.refresh(qs)
    # reload items
    result = await db.scalar(
        select(QuestionSet)
        .where(QuestionSet.id == qs.id)
        .options(selectinload(QuestionSet.items), selectinload(QuestionSet.creator))
    )
    return _set_to_out(result, result.creator.nickname)


# ── 내 맵 목록 ────────────────────────────────────────────────────────


@router.get("/my", response_model=list[QuestionSetBrief])
async def my_question_sets(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> list[QuestionSetBrief]:
    rows = await db.execute(
        select(
            QuestionSet,
            func.count(QuestionSetItem.id).label("item_count"),
            User.nickname.label("creator_nickname"),
        )
        .outerjoin(QuestionSetItem, QuestionSetItem.set_id == QuestionSet.id)
        .join(User, User.id == QuestionSet.creator_id)
        .where(QuestionSet.creator_id == user_id)
        .group_by(QuestionSet.id, User.nickname)
        .order_by(QuestionSet.updated_at.desc())
    )
    return [_set_to_brief(r.QuestionSet, r.item_count, r.creator_nickname) for r in rows]


# ── 공개 맵 검색 / 인기맵 ─────────────────────────────────────────────


@router.get("/browse", response_model=list[QuestionSetBrief])
async def browse_question_sets(
    q: str | None = Query(default=None, description="이름 검색"),
    tag: str | None = Query(default=None, description="테마 필터 (예: 역사)"),
    sort: str = Query(default="popular", description="popular | recent"),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=50),
    db: AsyncSession = Depends(get_session),
) -> list[QuestionSetBrief]:
    stmt = (
        select(
            QuestionSet,
            func.count(QuestionSetItem.id).label("item_count"),
            User.nickname.label("creator_nickname"),
        )
        .outerjoin(QuestionSetItem, QuestionSetItem.set_id == QuestionSet.id)
        .join(User, User.id == QuestionSet.creator_id)
        .where(QuestionSet.is_public.is_(True))
    )
    if q:
        stmt = stmt.where(QuestionSet.name.ilike(f"%{q}%"))
    if tag:
        stmt = stmt.where(QuestionSet.tags.any(tag))  # type: ignore[arg-type]

    order = (
        QuestionSet.play_count.desc() if sort == "popular" else QuestionSet.updated_at.desc()
    )
    stmt = stmt.group_by(QuestionSet.id, User.nickname).order_by(order).offset(offset).limit(limit)

    rows = await db.execute(stmt)
    return [_set_to_brief(r.QuestionSet, r.item_count, r.creator_nickname) for r in rows]


@router.get("/popular", response_model=list[QuestionSetBrief])
async def popular_question_sets(
    db: AsyncSession = Depends(get_session),
) -> list[QuestionSetBrief]:
    rows = await db.execute(
        select(
            QuestionSet,
            func.count(QuestionSetItem.id).label("item_count"),
            User.nickname.label("creator_nickname"),
        )
        .outerjoin(QuestionSetItem, QuestionSetItem.set_id == QuestionSet.id)
        .join(User, User.id == QuestionSet.creator_id)
        .where(QuestionSet.is_public.is_(True))
        .group_by(QuestionSet.id, User.nickname)
        .order_by(QuestionSet.play_count.desc())
        .limit(20)
    )
    return [_set_to_brief(r.QuestionSet, r.item_count, r.creator_nickname) for r in rows]


# ── 코드로 가져오기 (다운로드) ────────────────────────────────────────


@router.get("/by-code/{code}", response_model=QuestionSetOut)
async def get_by_code(
    code: str,
    db: AsyncSession = Depends(get_session),
) -> QuestionSetOut:
    code = code_util.normalize(code)
    qs = await db.scalar(
        select(QuestionSet)
        .where(QuestionSet.code == code)
        .options(selectinload(QuestionSet.items), selectinload(QuestionSet.creator))
    )
    if not qs:
        raise HTTPException(404, "맵을 찾을 수 없어요")
    if not qs.is_public:
        raise HTTPException(403, "비공개 맵이에요")
    return _set_to_out(qs, qs.creator.nickname)


# ── 상세 조회 ─────────────────────────────────────────────────────────


@router.get("/{set_id}", response_model=QuestionSetOut)
async def get_question_set(
    set_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> QuestionSetOut:
    qs = await db.scalar(
        select(QuestionSet)
        .where(QuestionSet.id == set_id)
        .options(selectinload(QuestionSet.items), selectinload(QuestionSet.creator))
    )
    if not qs:
        raise HTTPException(404, "맵을 찾을 수 없어요")
    if not qs.is_public and qs.creator_id != user_id:
        raise HTTPException(403, "비공개 맵이에요")
    return _set_to_out(qs, qs.creator.nickname)


# ── 수정 / 삭제 ───────────────────────────────────────────────────────


@router.put("/{set_id}", response_model=QuestionSetOut)
async def update_question_set(
    set_id: str,
    body: QuestionSetUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> QuestionSetOut:
    qs = await db.scalar(
        select(QuestionSet)
        .where(QuestionSet.id == set_id)
        .options(selectinload(QuestionSet.items), selectinload(QuestionSet.creator))
    )
    if not qs:
        raise HTTPException(404, "맵을 찾을 수 없어요")
    if qs.creator_id != user_id:
        raise HTTPException(403, "내 맵만 수정할 수 있어요")

    if body.name is not None:
        qs.name = body.name
    if body.description is not None:
        qs.description = body.description
    if body.is_public is not None:
        qs.is_public = body.is_public
    if body.tags is not None:
        qs.tags = body.tags
    qs.updated_at = datetime.now(UTC)

    await db.commit()
    await db.refresh(qs)
    return _set_to_out(qs, qs.creator.nickname)


@router.delete("/{set_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_question_set(
    set_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> None:
    qs = await db.get(QuestionSet, set_id)
    if not qs:
        raise HTTPException(404, "맵을 찾을 수 없어요")
    if qs.creator_id != user_id:
        raise HTTPException(403, "내 맵만 삭제할 수 있어요")
    await db.delete(qs)
    await db.commit()


# ── 문제 추가 / 수정 / 삭제 ──────────────────────────────────────────


async def _require_owner(set_id: str, user_id: str, db: AsyncSession) -> QuestionSet:
    qs = await db.get(QuestionSet, set_id)
    if not qs:
        raise HTTPException(404, "맵을 찾을 수 없어요")
    if qs.creator_id != user_id:
        raise HTTPException(403, "내 맵만 수정할 수 있어요")
    return qs


@router.post("/{set_id}/questions", response_model=QuestionItemOut, status_code=201)
async def add_question(
    set_id: str,
    body: QuestionItemCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> QuestionItemOut:
    qs = await _require_owner(set_id, user_id, db)
    max_order = await db.scalar(
        select(func.max(QuestionSetItem.order)).where(QuestionSetItem.set_id == set_id)
    )
    item = QuestionSetItem(
        set_id=qs.id,
        prompt=body.prompt,
        answer=body.answer,
        answer_normalized=normalize_answer(body.answer),
        accepted_answers=[normalize_answer(a) for a in body.accepted_answers],
        category=body.category,
        difficulty=body.difficulty,
        hint=body.hint,
        order=(max_order or 0) + 1,
    )
    db.add(item)
    qs.updated_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(item)
    return _item_to_out(item)


@router.put("/{set_id}/questions/{question_id}", response_model=QuestionItemOut)
async def update_question(
    set_id: str,
    question_id: str,
    body: QuestionItemUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> QuestionItemOut:
    await _require_owner(set_id, user_id, db)
    item = await db.get(QuestionSetItem, question_id)
    if not item or item.set_id != set_id:
        raise HTTPException(404, "문제를 찾을 수 없어요")

    if body.prompt is not None:
        item.prompt = body.prompt
    if body.answer is not None:
        item.answer = body.answer
        item.answer_normalized = normalize_answer(body.answer)
    if body.accepted_answers is not None:
        item.accepted_answers = [normalize_answer(a) for a in body.accepted_answers]
    if body.category is not None:
        item.category = body.category
    if body.difficulty is not None:
        item.difficulty = body.difficulty
    if body.hint is not None:
        item.hint = body.hint

    await db.commit()
    await db.refresh(item)
    return _item_to_out(item)


@router.delete("/{set_id}/questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_question(
    set_id: str,
    question_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> None:
    await _require_owner(set_id, user_id, db)
    item = await db.get(QuestionSetItem, question_id)
    if not item or item.set_id != set_id:
        raise HTTPException(404, "문제를 찾을 수 없어요")
    await db.delete(item)
    await db.commit()


@router.post("/{set_id}/reorder", status_code=status.HTTP_204_NO_CONTENT)
async def reorder_questions(
    set_id: str,
    ordered_ids: list[str],
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_session),
) -> None:
    """Pass the full list of question IDs in desired order."""
    await _require_owner(set_id, user_id, db)
    for idx, qid in enumerate(ordered_ids):
        await db.execute(
            update(QuestionSetItem)
            .where(QuestionSetItem.id == qid, QuestionSetItem.set_id == set_id)
            .values(order=idx)
        )
    await db.commit()
