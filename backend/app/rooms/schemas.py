from datetime import datetime

from pydantic import BaseModel, Field


class RoomCreate(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    is_public: bool = True
    max_players: int = Field(default=30, ge=2, le=200)
    win_score: int = Field(default=20, ge=3, le=100)
    round_seconds: int = Field(default=30, ge=10, le=120)
    categories: list[str] = Field(default_factory=list)
    difficulty_min: int = Field(default=1, ge=1, le=5)
    difficulty_max: int = Field(default=5, ge=1, le=5)
    # 사용자가 만든 맵으로 출제할 경우 question_set_id 설정; None = 시스템 문제
    question_set_id: str | None = None


class RoomListItem(BaseModel):
    id: str
    code: str
    name: str
    is_public: bool
    player_count: int
    max_players: int
    status: str
    win_score: int
    created_at: datetime


class RoomDetail(RoomListItem):
    owner_id: str | None
    round_seconds: int
    categories: list[str]
    difficulty_min: int
    difficulty_max: int
    question_set_id: str | None
