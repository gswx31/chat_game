from app.questions.normalize import normalize_answer
from app.questions.sync import plan_sync, seed_row

SEED = [
    {
        "prompt": "한글을 창제한 왕은?",
        "answer": "세종대왕",
        "accepted": ["세종"],
        "category": "역사",
        "difficulty": 1,
    },
    {
        "prompt": "임진왜란이 시작된 해는?",
        "answer": "1592",
        "accepted": ["1592년"],
        "category": "역사",
        "difficulty": 1,
    },
]


def _db_row(item: dict, row_id: str) -> dict:
    return {"id": row_id, **seed_row(item)}


def test_seed_row_normalizes_answer_and_accepted():
    row = seed_row(
        {
            "prompt": "p",
            "answer": "H2O",
            "accepted": ["h2o", "에이치 투 오", " "],
            "category": "과학",
            "difficulty": 1,
        }
    )
    assert row["answer_normalized"] == "h2o"
    # duplicates of the canonical form and blanks are dropped, spaces removed
    assert row["accepted_answers"] == ["h2o", "에이치투오"]
    assert row["hint"] is None


def test_empty_db_inserts_everything():
    plan = plan_sync([], SEED)
    assert [r["prompt"] for r in plan.insert] == [q["prompt"] for q in SEED]
    assert not plan.update and not plan.delete


def test_identical_db_is_a_noop():
    existing = [_db_row(q, f"id{i}") for i, q in enumerate(SEED)]
    assert plan_sync(existing, SEED).unchanged_only


def test_changed_fields_become_updates_not_reinserts():
    existing = [_db_row(q, f"id{i}") for i, q in enumerate(SEED)]
    fixed = [dict(SEED[0], accepted=["세종", "세종대왕님"]), SEED[1]]
    plan = plan_sync(existing, fixed)
    assert not plan.insert and not plan.delete
    assert plan.update == [("id0", {"accepted_answers": ["세종", normalize_answer("세종대왕님")]})]


def test_question_removed_from_seed_is_deleted():
    stale = {
        "id": "old",
        "prompt": "옛날 문제",
        **{k: v for k, v in seed_row(SEED[0]).items() if k != "prompt"},
    }
    existing = [stale] + [_db_row(q, f"id{i}") for i, q in enumerate(SEED)]
    plan = plan_sync(existing, SEED)
    assert plan.delete == ["old"]
    assert not plan.insert and not plan.update


def test_reworded_prompt_is_replaced():
    existing = [_db_row(q, f"id{i}") for i, q in enumerate(SEED)]
    reworded = [dict(SEED[0], prompt="훈민정음을 만든 조선의 왕은?"), SEED[1]]
    plan = plan_sync(existing, reworded)
    assert plan.delete == ["id0"]
    assert [r["prompt"] for r in plan.insert] == ["훈민정음을 만든 조선의 왕은?"]


def test_duplicate_rows_for_one_prompt_collapse_to_one():
    existing = [_db_row(SEED[0], "a"), _db_row(SEED[0], "b"), _db_row(SEED[1], "c")]
    plan = plan_sync(existing, SEED)
    assert plan.delete == ["b"]
    assert not plan.insert and not plan.update
