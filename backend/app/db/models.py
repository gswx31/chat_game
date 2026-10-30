from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import (
    ARRAY,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


def _uuid() -> str:
    return uuid4().hex


def _now() -> datetime:
    return datetime.now(UTC)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    # Firebase UID — unique per Google/anonymous account, null for legacy guest rows
    firebase_uid: Mapped[str | None] = mapped_column(
        String(128), nullable=True, unique=True, index=True
    )
    nickname: Mapped[str] = mapped_column(String(40), nullable=False)
    email: Mapped[str | None] = mapped_column(String(200), nullable=True)
    photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_guest: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    # Set by an operator (scripts/moderation.py) after a report; None = in good standing.
    suspended_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class Question(Base):
    """System/seed trivia questions. `answer_normalized` is lowercased +
    whitespace-stripped for comparison; `accepted_answers` holds alternates."""

    __tablename__ = "questions"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    prompt: Mapped[str] = mapped_column(Text, nullable=False)
    answer: Mapped[str] = mapped_column(String(120), nullable=False)
    answer_normalized: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    accepted_answers: Mapped[list[str]] = mapped_column(ARRAY(String(120)), default=list)
    category: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    difficulty: Mapped[int] = mapped_column(Integer, nullable=False, default=2)
    hint: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class QuestionSet(Base):
    """User-created question set (맵). Share via `code` like a room code.
    `is_public=False` means it won't appear in browse/search — private use only."""

    __tablename__ = "question_sets"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    code: Mapped[str] = mapped_column(String(8), nullable=False, unique=True, index=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    description: Mapped[str | None] = mapped_column(String(300), nullable=True)
    creator_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    is_public: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # Themes the set covers — used for browse filtering (e.g. ["과학", "역사"])
    tags: Mapped[list[str]] = mapped_column(ARRAY(String(40)), default=list)
    play_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    items: Mapped[list["QuestionSetItem"]] = relationship(
        back_populates="question_set", cascade="all, delete", order_by="QuestionSetItem.order"
    )
    creator: Mapped[User] = relationship()


class QuestionSetItem(Base):
    """A single question inside a QuestionSet."""

    __tablename__ = "question_set_items"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    set_id: Mapped[str] = mapped_column(
        ForeignKey("question_sets.id", ondelete="CASCADE"), nullable=False, index=True
    )
    prompt: Mapped[str] = mapped_column(Text, nullable=False)
    answer: Mapped[str] = mapped_column(String(120), nullable=False)
    answer_normalized: Mapped[str] = mapped_column(String(120), nullable=False)
    accepted_answers: Mapped[list[str]] = mapped_column(ARRAY(String(120)), default=list)
    # Theme of this specific question (과학, 사회, 역사, 일반상식 ...)
    category: Mapped[str] = mapped_column(String(40), nullable=False)
    difficulty: Mapped[int] = mapped_column(Integer, nullable=False, default=2)
    hint: Mapped[str | None] = mapped_column(String(120), nullable=True)
    order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    question_set: Mapped[QuestionSet] = relationship(back_populates="items")


class Room(Base):
    __tablename__ = "rooms"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=_uuid)
    code: Mapped[str] = mapped_column(String(6), nullable=False, unique=True, index=True)
    name: Mapped[str] = mapped_column(String(60), nullable=False)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    owner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    max_players: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    win_score: Mapped[int] = mapped_column(Integer, default=20, nullable=False)
    round_seconds: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    categories: Mapped[list[str]] = mapped_column(ARRAY(String(40)), default=list)
    difficulty_min: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    difficulty_max: Mapped[int] = mapped_column(Integer, default=5, nullable=False)
    # If set, game uses this question set instead of system questions
    question_set_id: Mapped[str | None] = mapped_column(
        ForeignKey("question_sets.id", ondelete="SET NULL"), nullable=True
    )
    status: Mapped[str] = mapped_column(String(20), default="waiting", nullable=False)
    # waiting | playing | ended
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    last_active_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, nullable=False, index=True
    )
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    members: Mapped[list["RoomMember"]] = relationship(back_populates="room", cascade="all, delete")


class RoomMember(Base):
    __tablename__ = "room_members"
    __table_args__ = (UniqueConstraint("room_id", "user_id", name="uq_room_user"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    room_id: Mapped[str] = mapped_column(ForeignKey("rooms.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    room: Mapped[Room] = relationship(back_populates="members")


class GameResult(Base):
    """One row per player per finished game -- the data behind "내 전적".

    Deliberately not tied to ``rooms``: idle rooms are deleted 30 minutes after a game
    (taking their ``room_members`` with them) and a rematch reuses the room and resets
    its scores, so neither can serve as history.
    """

    __tablename__ = "game_results"
    __table_args__ = (Index("ix_game_results_user_played", "user_id", "played_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    played_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    room_name: Mapped[str] = mapped_column(String(60), nullable=False)
    room_code: Mapped[str] = mapped_column(String(6), nullable=False, default="")
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    rank: Mapped[int] = mapped_column(Integer, nullable=False)
    player_count: Mapped[int] = mapped_column(Integer, nullable=False)
    win_score: Mapped[int] = mapped_column(Integer, nullable=False)
    winner_nickname: Mapped[str | None] = mapped_column(String(40), nullable=True)


class Report(Base):
    """A player's report of another player's behaviour (Google Play UGC policy).

    Chat is not stored, so the reporter's client sends the offending line along with the
    report; ``target_nickname`` is a snapshot because nicknames can be changed afterwards.
    ``status``: open -> actioned (operator suspended the target) | dismissed.
    """

    __tablename__ = "reports"
    __table_args__ = (
        Index("ix_reports_status_created", "status", "created_at"),
        Index("ix_reports_reporter_created", "reporter_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    reporter_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    target_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    target_nickname: Mapped[str] = mapped_column(String(40), nullable=False)
    reason: Mapped[str] = mapped_column(String(20), nullable=False)
    detail: Mapped[str | None] = mapped_column(Text, nullable=True)
    message_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    room_code: Mapped[str | None] = mapped_column(String(6), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="open", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class UserBlock(Base):
    """``blocker`` no longer sees ``blocked``'s chat lines."""

    __tablename__ = "user_blocks"
    __table_args__ = (UniqueConstraint("blocker_id", "blocked_id", name="uq_user_block"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    blocker_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    blocked_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
