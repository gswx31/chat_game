"""Make the ``questions`` table match ``seed_data.SEED`` exactly.

``seed_data.py`` is the single source of truth for system questions. The table
holds nothing else (user-made questions live in ``question_set_items``), and no
other table references it, so deleting rows that left the seed is safe.

Rows are matched on ``prompt``. Editing a prompt therefore reads as "old one
gone, new one added" -- which is what we want when a wrong question is fixed.
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Question
from app.questions.normalize import normalize_answer
from app.questions.seed_data import SEED

# Columns we own on a seeded row; anything else (id, created_at) is left alone.
_FIELDS = ("answer", "answer_normalized", "accepted_answers", "category", "difficulty", "hint")


@dataclass
class SyncPlan:
    insert: list[dict[str, Any]] = field(default_factory=list)
    update: list[tuple[str, dict[str, Any]]] = field(default_factory=list)  # (row id, changes)
    delete: list[str] = field(default_factory=list)  # row ids

    @property
    def unchanged_only(self) -> bool:
        return not (self.insert or self.update or self.delete)


def seed_row(item: Mapping[str, Any]) -> dict[str, Any]:
    """Seed dict -> the column values we store."""
    accepted: list[str] = []
    for alt in item.get("accepted", []):
        norm = normalize_answer(alt)
        if norm and norm not in accepted:
            accepted.append(norm)
    return {
        "prompt": item["prompt"],
        "answer": item["answer"],
        "answer_normalized": normalize_answer(item["answer"]),
        "accepted_answers": accepted,
        "category": item["category"],
        "difficulty": item.get("difficulty", 2),
        "hint": item.get("hint") or None,
    }


def plan_sync(existing: Iterable[Mapping[str, Any]], seed: Iterable[Mapping[str, Any]]) -> SyncPlan:
    """Pure diff between DB rows (dicts incl. ``id``/``prompt``) and the seed."""
    wanted = {row["prompt"]: row for row in map(seed_row, seed)}
    plan = SyncPlan()
    seen: set[str] = set()

    for row in existing:
        prompt = row["prompt"]
        target = wanted.get(prompt)
        if target is None or prompt in seen:
            # Gone from the seed, or a stray duplicate of a prompt we already kept.
            plan.delete.append(row["id"])
            continue
        seen.add(prompt)
        changes = {k: target[k] for k in _FIELDS if _differs(row.get(k), target[k])}
        if changes:
            plan.update.append((row["id"], changes))

    plan.insert = [row for prompt, row in wanted.items() if prompt not in seen]
    return plan


def _differs(current: Any, wanted: Any) -> bool:
    if isinstance(wanted, list):
        return list(current or []) != wanted
    return current != wanted


async def sync_questions(db: AsyncSession, seed: Iterable[Mapping[str, Any]] = SEED) -> SyncPlan:
    """Apply the plan inside the caller's session (caller commits)."""
    rows = (
        (
            await db.execute(
                select(Question.id, Question.prompt, *(getattr(Question, f) for f in _FIELDS))
            )
        )
        .mappings()
        .all()
    )
    plan = plan_sync([dict(r) for r in rows], seed)

    if plan.delete:
        await db.execute(delete(Question).where(Question.id.in_(plan.delete)))
    for row_id, changes in plan.update:
        question = await db.get(Question, row_id)
        for key, value in changes.items():
            setattr(question, key, value)
    for row in plan.insert:
        db.add(Question(**row))
    return plan
