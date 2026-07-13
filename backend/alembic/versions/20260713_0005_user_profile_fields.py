"""user profile fields: firebase_uid, email, photo_url

Revision ID: 20260713_0005
Revises: 20260710_0004
Create Date: 2026-07-13
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "20260713_0005"
down_revision = "20260710_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("firebase_uid", sa.String(128), nullable=True))
    op.add_column("users", sa.Column("email", sa.String(200), nullable=True))
    op.add_column("users", sa.Column("photo_url", sa.String(500), nullable=True))
    op.create_unique_constraint("uq_users_firebase_uid", "users", ["firebase_uid"])
    op.create_index("ix_users_firebase_uid", "users", ["firebase_uid"])


def downgrade() -> None:
    op.drop_index("ix_users_firebase_uid", table_name="users")
    op.drop_constraint("uq_users_firebase_uid", "users", type_="unique")
    op.drop_column("users", "photo_url")
    op.drop_column("users", "email")
    op.drop_column("users", "firebase_uid")
