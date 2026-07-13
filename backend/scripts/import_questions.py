"""CSV importer for the questions table.

CSV columns (header required):

    prompt,answer,accepted,category,difficulty,hint

- ``accepted`` is a ``|``-separated list of alternate spellings (optional).
- ``difficulty`` is 1..5 (default 2).
- ``hint`` is optional. If omitted, chosung is auto-generated at play time.

Usage:

    python -m scripts.import_questions scripts/example_questions.csv

Idempotency: rows whose ``(prompt, answer_normalized)`` already exist are skipped.
"""

from __future__ import annotations

import asyncio
import csv
import sys
from pathlib import Path

from sqlalchemy import select

from app.db.models import Question
from app.db.session import SessionLocal, close_engine
from app.questions.normalize import normalize_answer


async def import_csv(path: Path) -> tuple[int, int]:
    inserted = 0
    skipped = 0
    async with SessionLocal() as db:
        with path.open(encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                prompt = (row.get("prompt") or "").strip()
                answer = (row.get("answer") or "").strip()
                if not prompt or not answer:
                    skipped += 1
                    continue
                norm = normalize_answer(answer)
                exists = await db.scalar(
                    select(Question.id).where(
                        Question.prompt == prompt,
                        Question.answer_normalized == norm,
                    )
                )
                if exists:
                    skipped += 1
                    continue
                accepted_raw = (row.get("accepted") or "").strip()
                accepted = [
                    normalize_answer(a) for a in accepted_raw.split("|") if a.strip()
                ]
                try:
                    difficulty = int(row.get("difficulty") or 2)
                except ValueError:
                    difficulty = 2
                difficulty = max(1, min(5, difficulty))
                db.add(
                    Question(
                        prompt=prompt,
                        answer=answer,
                        answer_normalized=norm,
                        accepted_answers=accepted,
                        category=(row.get("category") or "일반상식").strip() or "일반상식",
                        difficulty=difficulty,
                        hint=(row.get("hint") or "").strip() or None,
                    )
                )
                inserted += 1
        await db.commit()
    return inserted, skipped


async def _amain(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: python -m scripts.import_questions <path.csv>")
        return 2
    path = Path(argv[1])
    if not path.exists():
        print(f"not found: {path}")
        return 1
    try:
        inserted, skipped = await import_csv(path)
        print(f"inserted={inserted} skipped={skipped}")
        return 0
    finally:
        await close_engine()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_amain(sys.argv)))
