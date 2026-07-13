from datetime import datetime

from pydantic import BaseModel, Field

THEMES = [
    "일반상식",
    "역사",
    "과학",
    "사회",
    "지리",
    "문학",
    "예술",
    "스포츠",
    "IT",
    "수학",
    "영어",
    "기타",
]


# ---- QuestionSetItem ----


class QuestionItemCreate(BaseModel):
    prompt: str = Field(min_length=1, max_length=500)
    answer: str = Field(min_length=1, max_length=120)
    accepted_answers: list[str] = Field(default_factory=list, max_length=10)
    category: str = Field(min_length=1, max_length=40)
    difficulty: int = Field(default=2, ge=1, le=5)
    hint: str | None = Field(default=None, max_length=120)


class QuestionItemUpdate(BaseModel):
    prompt: str | None = Field(default=None, min_length=1, max_length=500)
    answer: str | None = Field(default=None, min_length=1, max_length=120)
    accepted_answers: list[str] | None = Field(default=None, max_length=10)
    category: str | None = Field(default=None, min_length=1, max_length=40)
    difficulty: int | None = Field(default=None, ge=1, le=5)
    hint: str | None = None


class QuestionItemOut(BaseModel):
    id: str
    set_id: str
    prompt: str
    answer: str
    accepted_answers: list[str]
    category: str
    difficulty: int
    hint: str | None
    order: int


# ---- QuestionSet ----


class QuestionSetCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=300)
    is_public: bool = True
    tags: list[str] = Field(default_factory=list, max_length=10)
    items: list[QuestionItemCreate] = Field(default_factory=list)


class QuestionSetUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=300)
    is_public: bool | None = None
    tags: list[str] | None = None


class QuestionSetBrief(BaseModel):
    """Used in list/browse responses — no question content."""
    id: str
    code: str
    name: str
    description: str | None
    creator_id: str
    creator_nickname: str
    is_public: bool
    tags: list[str]
    play_count: int
    item_count: int
    created_at: datetime
    updated_at: datetime


class QuestionSetOut(QuestionSetBrief):
    """Full detail with all questions — returned on fetch-by-code / my-set detail."""
    items: list[QuestionItemOut]
