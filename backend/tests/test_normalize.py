from app.questions.normalize import normalize_answer


def test_strips_spaces_and_punctuation():
    assert normalize_answer("세종 대왕!") == "세종대왕"
    assert normalize_answer("H2O") == "h2o"
    assert normalize_answer("  레오나르도 다 빈치  ") == "레오나르도다빈치"
