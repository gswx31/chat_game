import asyncio

import pytest
from pydantic import ValidationError

from app.question_sets.router import list_themes
from app.question_sets.schemas import (
    LEGACY_CATEGORIES,
    QuestionItemCreate,
    QuestionItemUpdate,
    QuestionSetCreate,
    QuestionSetUpdate,
)
from app.questions.bank import CATEGORIES


def item(category: str) -> dict:
    return {"prompt": "대한민국의 수도는?", "answer": "서울", "category": category}


def test_maps_use_the_room_categories():
    assert asyncio.run(list_themes()) == CATEGORIES
    for name in CATEGORIES:
        assert QuestionItemCreate(**item(name)).category == name


def test_names_from_older_app_builds_are_translated():
    assert QuestionItemCreate(**item("역사")).category == "한국사"
    assert QuestionItemCreate(**item(" 문학 ")).category == "예술"
    assert QuestionItemUpdate(category="기타").category == "일반상식"
    assert set(LEGACY_CATEGORIES.values()) <= set(CATEGORIES)


def test_unknown_category_is_rejected():
    with pytest.raises(ValidationError):
        QuestionItemCreate(**item("우주"))
    with pytest.raises(ValidationError):
        QuestionItemUpdate(category="우주")


def test_update_without_a_category_leaves_it_alone():
    assert QuestionItemUpdate(prompt="새 문제").category is None


def test_tags_are_translated_and_deduplicated():
    body = QuestionSetCreate(name="맵", tags=["역사", "한국사", "문학", "과학"])
    assert body.tags == ["한국사", "예술", "과학"]
    assert QuestionSetUpdate(tags=["수학"]).tags == ["과학"]
    assert QuestionSetUpdate(name="이름만").tags is None
    with pytest.raises(ValidationError):
        QuestionSetCreate(name="맵", tags=["우주"])
