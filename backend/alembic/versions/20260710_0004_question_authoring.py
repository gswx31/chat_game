"""question sets (맵 시스템): QuestionSet + QuestionSetItem tables,
question_set_id on rooms, max_players default raised to 30

Revision ID: 20260710_0004
Revises: 20260519_0003
Create Date: 2026-07-10
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260710_0004"
down_revision = "20260519_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── question_sets ──────────────────────────────────────────────────
    op.create_table(
        "question_sets",
        sa.Column("id", sa.String(32), primary_key=True),
        sa.Column("code", sa.String(8), nullable=False, unique=True),
        sa.Column("name", sa.String(80), nullable=False),
        sa.Column("description", sa.String(300), nullable=True),
        sa.Column(
            "creator_id",
            sa.String(32),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("is_public", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("tags", sa.ARRAY(sa.String(40)), nullable=False, server_default="{}"),
        sa.Column("play_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_question_sets_code", "question_sets", ["code"], unique=True)
    op.create_index("ix_question_sets_creator_id", "question_sets", ["creator_id"])

    # ── question_set_items ────────────────────────────────────────────
    op.create_table(
        "question_set_items",
        sa.Column("id", sa.String(32), primary_key=True),
        sa.Column(
            "set_id",
            sa.String(32),
            sa.ForeignKey("question_sets.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("prompt", sa.Text(), nullable=False),
        sa.Column("answer", sa.String(120), nullable=False),
        sa.Column("answer_normalized", sa.String(120), nullable=False),
        sa.Column("accepted_answers", sa.ARRAY(sa.String(120)), nullable=False, server_default="{}"),
        sa.Column("category", sa.String(40), nullable=False),
        sa.Column("difficulty", sa.Integer(), nullable=False, server_default="2"),
        sa.Column("hint", sa.String(120), nullable=True),
        sa.Column("order", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_index("ix_question_set_items_set_id", "question_set_items", ["set_id"])

    # ── rooms: add question_set_id ─────────────────────────────────────
    op.add_column(
        "rooms",
        sa.Column(
            "question_set_id",
            sa.String(32),
            sa.ForeignKey("question_sets.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )

    # ── rooms: bump max_players default to 30 ─────────────────────────
    op.alter_column("rooms", "max_players", server_default="30")


def downgrade() -> None:
    op.alter_column("rooms", "max_players", server_default="8")
    op.drop_column("rooms", "question_set_id")
    op.drop_index("ix_question_set_items_set_id", table_name="question_set_items")
    op.drop_table("question_set_items")
    op.drop_index("ix_question_sets_creator_id", table_name="question_sets")
    op.drop_index("ix_question_sets_code", table_name="question_sets")
    op.drop_table("question_sets")
