"""Invariants the question bank must hold (see app/questions/bank/_check.py for the per-item
rules: answer not in prompt, hints never reveal the answer, "…년" accepted for years, nothing
time-sensitive, no lyrics, typeable answers)."""

from collections import Counter

from app.questions.bank._check import check_items, cross_leaks
from app.questions.normalize import normalize_answer
from app.questions.seed_data import CATEGORIES, SEED


def test_every_item_passes_the_per_item_checks():
    problems = check_items(SEED)
    assert not problems, "\n".join(problems[:30])


def test_bank_is_big_enough_to_not_repeat_quickly():
    # Default room = 20 points; a few games in a row should not show the same questions.
    assert len(SEED) >= 700, len(SEED)


def test_every_category_is_deep_enough_to_play_a_whole_game():
    counts = Counter(q["category"] for q in SEED)
    thin = {c: counts[c] for c in CATEGORIES if counts[c] < 30}
    assert not thin, thin


def test_every_declared_category_is_used_and_nothing_is_undeclared():
    used = {q["category"] for q in SEED}
    assert used == set(CATEGORIES), (set(CATEGORIES) - used, used - set(CATEGORIES))


def test_the_bank_stays_mainstream_not_pub_quiz():
    """The reason for the rewrite: the first bank was too hard. 상(hard) must stay a small
    minority and 하(easy) the biggest group."""
    counts = Counter(q["difficulty"] for q in SEED)
    total = len(SEED)
    assert counts[3] / total <= 0.15, f"too many hard questions: {counts[3]}/{total}"
    assert counts[1] / total >= 0.40, f"too few easy questions: {counts[1]}/{total}"


def test_choseong_quizzes_follow_the_format_and_reveal_the_first_syllable():
    items = [q for q in SEED if q["category"] == "초성퀴즈"]
    assert len(items) >= 30
    for q in items:
        assert q["prompt"].startswith("[초성퀴즈"), q["prompt"]
        # the prompt already shows the 초성, so the halfway hint must add something
        assert q.get("hint") and q["hint"][0] == q["answer"][0], q


def test_the_same_answer_does_not_come_up_over_and_over():
    answers = Counter(normalize_answer(q["answer"]) for q in SEED)
    repeated = {a: n for a, n in answers.items() if n > 3 and len(a) > 1}
    assert not repeated, repeated


def test_free_points_from_answers_visible_in_other_prompts_stay_rare():
    """Informational leaks ("프랑스" written in another question) are tolerated in small
    numbers; a flood means the prompts are telling the answers. A leak only costs a free point
    when both questions come up in the same game, which is far likelier inside one category
    (rooms often pick a category) than across the whole bank, hence the two limits. Prompts about
    actors and films name works and people that are answers elsewhere ("명량에서 이순신 장군을
    연기한 배우는?"), which is what the looser cross-category limit allows for."""
    leaks = cross_leaks(SEED, min_chars=3)
    category_of_prompt = {q["prompt"]: q["category"] for q in SEED}
    category_of_answer: dict[str, set[str]] = {}
    for q in SEED:
        category_of_answer.setdefault(q["answer"], set()).add(q["category"])
    same = [(a, p) for a, p in leaks if category_of_prompt[p] in category_of_answer.get(a, set())]
    assert len(same) <= len(SEED) * 0.06, (len(same), same[:10])
    assert len(leaks) <= len(SEED) * 0.12, (len(leaks), leaks[:10])


def test_award_and_survey_names_are_not_time_sensitive():
    from app.questions.bank._check import check_item

    base = {"answer": "로제", "category": "연예인", "difficulty": 2}
    assert not check_item(
        {**base, "prompt": "2026년 그래미 올해의 노래 후보에 오른 'APT.'를 부른 가수는?"}
    )
    assert not check_item({**base, "prompt": "2022년 한국갤럽 올해를 빛낸 가수 1위는?"})
    assert check_item({**base, "prompt": "올해 데뷔한 가수는?"})  # this one does expire
