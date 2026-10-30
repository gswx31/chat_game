"""Shared building blocks for the question bank modules."""

from __future__ import annotations

from functools import partial

from app.game.chosung import first_syllable_hint

# 난이도 (DB Integer): 하 = 거의 모두가 안다 / 중 = 대부분 안다 / 상 = 아는 사람은 바로 안다
하, 중, 상 = 1, 2, 3


def q(
    category: str,
    difficulty: int,
    prompt: str,
    answer: str,
    *accepted: str,
    hint: str | None = None,
) -> dict:
    item: dict = {
        "prompt": prompt,
        "answer": answer,
        "category": category,
        "difficulty": difficulty,
    }
    if accepted:
        item["accepted"] = list(accepted)
    if hint:
        item["hint"] = hint
    return item


def maker(category: str):
    """``ask = maker("과학")`` then ``ask(하, "질문?", "정답", "별칭")``."""
    return partial(q, category)


def choseong_maker(category: str = "초성퀴즈"):
    """초성 quizzes: the prompt shows the 초성, so the halfway hint reveals the first
    syllable instead of repeating the 초성."""

    def ask(difficulty: int, prompt: str, answer: str, *accepted: str) -> dict:
        return q(category, difficulty, prompt, answer, *accepted, hint=first_syllable_hint(answer))

    return ask
