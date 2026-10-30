"""safety: reports, user_blocks, users.suspended_until

Google Play's user-generated-content policy asks chat apps for an in-app way to report and
block users, and for the operator to act on reports.

Revision ID: 20261024_0008
Revises: 20261023_0007
Create Date: 2026-10-24
"""
from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "20261024_0008"
down_revision = "20261023_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("suspended_until", sa.DateTime(timezone=True), nullable=True))

    op.create_table(
        "reports",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "reporter_id",
            sa.String(32),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "target_id",
            sa.String(32),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("target_nickname", sa.String(40), nullable=False),
        sa.Column("reason", sa.String(20), nullable=False),
        sa.Column("detail", sa.Text(), nullable=True),
        sa.Column("message_text", sa.Text(), nullable=True),
        sa.Column("room_code", sa.String(6), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_reports_target_id", "reports", ["target_id"])
    op.create_index("ix_reports_status_created", "reports", ["status", "created_at"])
    op.create_index("ix_reports_reporter_created", "reports", ["reporter_id", "created_at"])

    op.create_table(
        "user_blocks",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "blocker_id",
            sa.String(32),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "blocked_id",
            sa.String(32),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("blocker_id", "blocked_id", name="uq_user_block"),
    )
    op.create_index("ix_user_blocks_blocker_id", "user_blocks", ["blocker_id"])


def downgrade() -> None:
    op.drop_index("ix_user_blocks_blocker_id", table_name="user_blocks")
    op.drop_table("user_blocks")
    op.drop_index("ix_reports_reporter_created", table_name="reports")
    op.drop_index("ix_reports_status_created", table_name="reports")
    op.drop_index("ix_reports_target_id", table_name="reports")
    op.drop_table("reports")
    op.drop_column("users", "suspended_until")
