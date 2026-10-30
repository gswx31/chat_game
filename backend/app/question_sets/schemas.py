from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.questions.bank import CATEGORIES

# Maps use the room categories (bank.CATEGORIES) for both question categories and map tags.
# Installed copies of the app still offer the old map-only list, so those names are
# translated to the closest room category (the bank files literature under 예술).
LEGACY_CATEGORIES = {
    "역사": "한국사",
    "문학": "예술",
    "문화": "예술",
    "수학": "과학",
    "일반": "일반상식",
    "기타": "일반상식",
}


def canonical_category(name: str) -> str:
    name = name.strip()
    name = LEGACY_CATEGORIES.get(name, name)
    if name not in CATEGORIES:
        raise ValueError(f"없는 카테고리예요: {name}")
    return name


def canonical_tags(tags: list[str]) -> list[str]:
    # translating can turn two tags into one ('역사' + '한국사')
    return list(dict.fromkeys(canonical_category(t) for t in tags))


# ---- QuestionSetItem ----


class QuestionItemCreate(BaseModel):
    prompt: str = Field(min_length=1, max_length=500)
    answer: str = Field(min_length=1, max_length=120)
    accepted_answers: list[str] = Field(default_factory=list, max_length=10)
    category: str = Field(min_length=1, max_length=40)
    difficulty: int = Field(default=2, ge=1, le=5)
    hint: str | None = Field(default=None, max_length=120)

    @field_validator("category")
    @classmethod
    def _known_category(cls, v: str) -> str:
        return canonical_category(v)


class QuestionItemUpdate(BaseModel):
    prompt: str | None = Field(default=None, min_length=1, max_length=500)
    answer: str | None = Field(default=None, min_length=1, max_length=120)
    accepted_answers: list[str] | None = Field(default=None, max_length=10)
    category: str | None = Field(default=None, min_length=1, max_length=40)
    difficulty: int | None = Field(default=None, ge=1, le=5)
    hint: str | None = None

    @field_validator("category")
    @classmethod
    def _known_category(cls, v: str | None) -> str | None:
        return None if v is None else canonical_category(v)


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

    @field_validator("tags")
    @classmethod
    def _known_tags(cls, v: list[str]) -> list[str]:
        return canonical_tags(v)


class QuestionSetUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=300)
    is_public: bool | None = None
    tags: list[str] | None = None

    @field_validator("tags")
    @classmethod
    def _known_tags(cls, v: list[str] | None) -> list[str] | None:
        return None if v is None else canonical_tags(v)


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
