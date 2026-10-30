"""game_results: permanent per-player game history ("내 전적")

Rooms are deleted 30 minutes after a game and a rematch reuses (and resets) the room, so
room_members cannot serve as history. This table is independent of rooms.

Existing finished rooms that still exist are backfilled once.

Revision ID: 20261023_0007
Revises: 20260716_0006
Create Date: 2026-10-23
"""
from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "20261023_0007"
down_revision = "20260716_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "game_results",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "user_id",
            sa.String(32),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("played_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("room_name", sa.String(60), nullable=False),
        sa.Column("room_code", sa.String(6), nullable=False, server_default=""),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("rank", sa.Integer(), nullable=False),
        sa.Column("player_count", sa.Integer(), nullable=False),
        sa.Column("win_score", sa.Integer(), nullable=False),
        sa.Column("winner_nickname", sa.String(40), nullable=True),
    )
    op.create_index("ix_game_results_user_played", "game_results", ["user_id", "played_at"])

    # One-time backfill from finished rooms that still exist and where somebody scored.
    op.execute(
        """
        INSERT INTO game_results
            (user_id, played_at, room_name, room_code, score, rank, player_count,
             win_score, winner_nickname)
        SELECT rm.user_id,
               COALESCE(r.ended_at, r.created_at),
               r.name,
               r.code,
               rm.score,
               RANK() OVER (PARTITION BY rm.room_id ORDER BY rm.score DESC),
               COUNT(*) OVER (PARTITION BY rm.room_id),
               r.win_score,
               (SELECT u2.nickname
                  FROM room_members m2 JOIN users u2 ON u2.id = m2.user_id
                 WHERE m2.room_id = rm.room_id
                 ORDER BY m2.score DESC, m2.id
                 LIMIT 1)
          FROM room_members rm
          JOIN rooms r ON r.id = rm.room_id
         WHERE r.status = 'ended'
           AND rm.room_id IN (
                SELECT room_id FROM room_members GROUP BY room_id HAVING MAX(score) > 0)
        """
    )


def downgrade() -> None:
    op.drop_index("ix_game_results_user_played", table_name="game_results")
    op.drop_table("game_results")
