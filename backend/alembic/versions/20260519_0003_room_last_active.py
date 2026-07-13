"""room last_active_at for idle-room cleanup

Revision ID: 20260519_0003
Revises: 20260519_0002
Create Date: 2026-05-19
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260519_0003"
down_revision = "20260519_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "rooms",
        sa.Column(
            "last_active_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_rooms_last_active_at", "rooms", ["last_active_at"])


def downgrade() -> None:
    op.drop_index("ix_rooms_last_active_at", table_name="rooms")
    op.drop_column("rooms", "last_active_at")
