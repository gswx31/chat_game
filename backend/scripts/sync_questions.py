"""Make the system ``questions`` table identical to ``app/questions/seed_data.py``.

    python -m scripts.sync_questions            # apply
    python -m scripts.sync_questions --dry-run  # just print what would change

Idempotent: a second run reports 0 changes. Safe to run on every deploy
(``fly.toml`` release_command does exactly that).
"""

from __future__ import annotations

import asyncio
import sys

from app.db.session import SessionLocal, close_engine
from app.questions.sync import sync_questions


async def _amain(argv: list[str]) -> int:
    dry_run = "--dry-run" in argv
    try:
        async with SessionLocal() as db:
            plan = await sync_questions(db)
            if dry_run:
                await db.rollback()
            else:
                await db.commit()
        label = "would" if dry_run else "did"
        print(
            f"{label}: insert={len(plan.insert)} update={len(plan.update)} "
            f"delete={len(plan.delete)}"
        )
        return 0
    finally:
        await close_engine()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_amain(sys.argv[1:])))
