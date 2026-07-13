"""room code + is_public

Revision ID: 20260519_0002
Revises: 20260519_0001
Create Date: 2026-05-19
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260519_0002"
down_revision = "20260519_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # code: backfill existing rows with random 6-char then enforce NOT NULL + UNIQUE.
    op.add_column("rooms", sa.Column("code", sa.String(6), nullable=True))
    op.execute(
        "UPDATE rooms "
        "SET code = UPPER(SUBSTRING(MD5(RANDOM()::text), 1, 6)) "
        "WHERE code IS NULL"
    )
    op.alter_column("rooms", "code", nullable=False)
    op.create_unique_constraint("uq_rooms_code", "rooms", ["code"])

    op.add_column(
        "rooms",
        sa.Column("is_public", sa.Boolean, nullable=False, server_default=sa.true()),
    )


def downgrade() -> None:
    op.drop_column("rooms", "is_public")
    op.drop_constraint("uq_rooms_code", "rooms", type_="unique")
    op.drop_column("rooms", "code")
