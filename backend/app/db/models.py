from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import (
    ARRAY,
    Boolean,
    DateTime,
    ForeignKey,
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
    owner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
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
    room_id: Mapped[str] = mapped_column(ForeignKey("rooms.id", ondelete="CASCADE"))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    room: Mapped[Room] = relationship(back_populates="members")
