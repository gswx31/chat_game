"""Add missing FK indexes: room_members(room_id, user_id), rooms(owner_id)

Revision ID: 20260716_0006
Revises: 20260713_0005
Create Date: 2026-07-16
"""
from __future__ import annotations

from alembic import op

revision = "20260716_0006"
down_revision = "20260713_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index("ix_room_members_room_id", "room_members", ["room_id"])
    op.create_index("ix_room_members_user_id", "room_members", ["user_id"])
    op.create_index("ix_rooms_owner_id", "rooms", ["owner_id"])


def downgrade() -> None:
    op.drop_index("ix_room_members_room_id", table_name="room_members")
    op.drop_index("ix_room_members_user_id", table_name="room_members")
    op.drop_index("ix_rooms_owner_id", table_name="rooms")
