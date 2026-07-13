"""initial schema

Revision ID: 20260519_0001
Revises:
Create Date: 2026-05-19
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260519_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(32), primary_key=True),
        sa.Column("nickname", sa.String(40), nullable=False),
        sa.Column("is_guest", sa.Boolean, nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "questions",
        sa.Column("id", sa.String(32), primary_key=True),
        sa.Column("prompt", sa.Text, nullable=False),
        sa.Column("answer", sa.String(120), nullable=False),
        sa.Column("answer_normalized", sa.String(120), nullable=False),
        sa.Column(
            "accepted_answers",
            sa.ARRAY(sa.String(120)),
            nullable=False,
            server_default="{}",
        ),
        sa.Column("category", sa.String(40), nullable=False),
        sa.Column("difficulty", sa.Integer, nullable=False, server_default="2"),
        sa.Column("hint", sa.String(120), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_questions_answer_normalized", "questions", ["answer_normalized"]
    )
    op.create_index("ix_questions_category", "questions", ["category"])

    op.create_table(
        "rooms",
        sa.Column("id", sa.String(32), primary_key=True),
        sa.Column("name", sa.String(60), nullable=False),
        sa.Column(
            "owner_id",
            sa.String(32),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("max_players", sa.Integer, nullable=False, server_default="8"),
        sa.Column("win_score", sa.Integer, nullable=False, server_default="20"),
        sa.Column("round_seconds", sa.Integer, nullable=False, server_default="30"),
        sa.Column(
            "categories", sa.ARRAY(sa.String(40)), nullable=False, server_default="{}"
        ),
        sa.Column("difficulty_min", sa.Integer, nullable=False, server_default="1"),
        sa.Column("difficulty_max", sa.Integer, nullable=False, server_default="5"),
        sa.Column("status", sa.String(20), nullable=False, server_default="waiting"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        "room_members",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column(
            "room_id",
            sa.String(32),
            sa.ForeignKey("rooms.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.String(32),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("score", sa.Integer, nullable=False, server_default="0"),
        sa.Column(
            "joined_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("room_id", "user_id", name="uq_room_user"),
    )


def downgrade() -> None:
    op.drop_table("room_members")
    op.drop_table("rooms")
    op.drop_index("ix_questions_category", table_name="questions")
    op.drop_index("ix_questions_answer_normalized", table_name="questions")
    op.drop_table("questions")
    op.drop_table("users")
