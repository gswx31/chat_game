from __future__ import annotations

from datetime import UTC, datetime

from app.db.models import User


def is_suspended(user: User | None, now: datetime | None = None) -> bool:
    """True while an operator's suspension of ``user`` has not yet run out."""
    until = user.suspended_until if user else None
    return until is not None and until > (now or datetime.now(UTC))
