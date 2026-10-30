"""Automatic checks for question-bank items (used by tests and ``scripts.check_bank``).

These encode the lessons from reviewing the first bank: answers leaked by the prompt or the
hint, year answers that reject "1592년", answers nobody can type, facts that expire.
"""

from __future__ import annotations

import re
from collections import Counter
from collections.abc import Iterable, Mapping
from typing import Any

from app.game.chosung import build_hint, first_syllable_hint, korean_chosung
from app.questions.bank import CATEGORIES
from app.questions.normalize import normalize_answer

_JAMO = re.compile(r"[ㄱ-ㅎ]")
# Facts that go stale. An evergreen bank must not contain them.
TIME_SENSITIVE = ("현재", "최근", "올해", "작년", "요즘", "신제품", "지금은")
# Not quiz-friendly in a chat game, or copyright-risky (lyrics / famous lines).
BANNED_STYLE = ("다음 중", "가사", "명대사", "대사는")
MAX_PROMPT_CHARS = 80
MAX_ANSWER_CHARS = 20


def check_item(item: Mapping[str, Any]) -> list[str]:
    """Problems with one item (empty list = fine)."""
    prompt = str(item.get("prompt", ""))
    answer = str(item.get("answer", ""))
    where = f"[{prompt[:40]}]"
    problems: list[str] = []

    if not prompt.strip():
        return [f"{where} empty prompt"]
    if not answer.strip():
        return [f"{where} empty answer"]
    if answer != answer.strip():
        problems.append(f"{where} answer has leading/trailing spaces")
    if item.get("category") not in CATEGORIES:
        problems.append(f"{where} unknown category {item.get('category')!r}")
    if item.get("difficulty") not in (1, 2, 3):
        problems.append(f"{where} difficulty must be 1, 2 or 3")
    if len(prompt) > MAX_PROMPT_CHARS:
        problems.append(f"{where} prompt longer than {MAX_PROMPT_CHARS} chars")

    norm_answer = normalize_answer(answer)
    if not norm_answer:
        return problems + [f"{where} answer is empty after normalizing"]
    if len(norm_answer) > MAX_ANSWER_CHARS:
        problems.append(f"{where} answer longer than {MAX_ANSWER_CHARS} chars (hard to type)")

    norm_prompt = normalize_answer(prompt)
    # A 1-char answer ("핵", "원") inevitably appears in some sentence; longer ones are leaks.
    if len(norm_answer) >= 2 and norm_answer in norm_prompt:
        problems.append(f"{where} the answer {answer!r} is written inside the prompt")

    # "올해의 노래"(Grammy), "올해의 선수", "올해를 빛낸 가수"(Gallup) are names of awards and
    # surveys, not "this year".
    evergreen = re.sub(r"올해(의|를 빛낸)", "", prompt)
    for word in TIME_SENSITIVE:
        if word in evergreen:
            problems.append(f"{where} time-sensitive word {word!r} (facts must not expire)")
    for word in BANNED_STYLE:
        if word in prompt:
            problems.append(f"{where} banned wording {word!r}")

    accepted = list(item.get("accepted", []))
    for alt in accepted:
        norm_alt = normalize_answer(alt)
        if not norm_alt:
            problems.append(f"{where} empty accepted answer {alt!r}")
        elif len(norm_alt) > 120:
            problems.append(f"{where} accepted answer too long")
        elif len(norm_alt) >= 2 and norm_alt in norm_prompt:
            problems.append(f"{where} accepted {alt!r} is written inside the prompt")

    if norm_answer.isdigit() and re.search(r"(해는\?|연도는\?|해\)?는\?)$", prompt):
        if f"{norm_answer}년" not in {normalize_answer(a) for a in accepted}:
            problems.append(f"{where} year answer must also accept {answer}년")

    hint = item.get("hint")
    shown = hint or build_hint(answer)
    pool = {norm_answer} | {normalize_answer(a) for a in accepted}
    if normalize_answer(shown) in pool:
        problems.append(f"{where} the hint shown to players equals the answer")
    if hint:
        chosung_only = "".join(c for c in korean_chosung(answer) if _JAMO.fullmatch(c))
        if hint not in (chosung_only, first_syllable_hint(answer)):
            problems.append(
                f"{where} hint {hint!r} must be the 초성 {chosung_only!r} or the "
                f"first-syllable form {first_syllable_hint(answer)!r}"
            )
    return problems


def check_items(items: Iterable[Mapping[str, Any]]) -> list[str]:
    """Per-item problems plus duplicate prompts."""
    items = list(items)
    problems = [p for item in items for p in check_item(item)]
    seen = Counter(normalize_answer(str(i.get("prompt", ""))) for i in items)
    problems += [f"duplicate prompt: {p[:40]}" for p, n in seen.items() if n > 1]
    return problems


def cross_leaks(items: Iterable[Mapping[str, Any]], min_chars: int = 3) -> list[tuple[str, str]]:
    """(answer, other prompt) pairs where one question's answer is written in another
    question's prompt. Informational: a few are unavoidable ("프랑스"), but they are free
    points when both come up in one game, so avoid the easy ones."""
    items = list(items)
    prompts = [(i, normalize_answer(str(i["prompt"]))) for i in items]
    out: list[tuple[str, str]] = []
    for a in items:
        norm = normalize_answer(str(a["answer"]))
        if len(norm) < min_chars or norm.isdigit():
            continue
        for b, norm_prompt in prompts:
            if b is not a and norm in norm_prompt and a["answer"] != b["answer"]:
                out.append((str(a["answer"]), str(b["prompt"])))
    return out
