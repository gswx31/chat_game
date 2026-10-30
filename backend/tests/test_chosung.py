from app.game.chosung import build_hint, korean_chosung


def test_simple_hangul():
    assert korean_chosung("서울") == "ㅅㅇ"


def test_multi_char_hangul():
    assert korean_chosung("세종대왕") == "ㅅㅈㄷㅇ"


def test_passes_through_ascii_and_digits():
    assert korean_chosung("ABC 123") == "ABC 123"


def test_mixed_hangul_and_other():
    assert korean_chosung("서울 abc") == "ㅅㅇ abc"


def test_double_consonant_initial():
    # 까 (0xAE4C) → initial index 1 = ㄲ
    assert korean_chosung("까") == "ㄲ"


def test_empty_string():
    assert korean_chosung("") == ""


# --- build_hint: the auto hint must never be (or contain) the answer itself ---


def test_build_hint_hangul_uses_chosung():
    assert build_hint("세종대왕") == "ㅅㅈㄷㅇ"


def test_build_hint_year_is_masked_not_leaked():
    assert build_hint("1592") == "1○○○"


def test_build_hint_keeps_separators_and_shape():
    assert build_hint("42.195") == "4○.○○○"


def test_build_hint_latin_formula_and_acronym():
    assert build_hint("H2O") == "H○○"
    assert build_hint("FIFA") == "F○○○"


def test_build_hint_very_short_answer_reveals_nothing():
    assert build_hint("Au") == "○○"
    assert build_hint("H") == "○"
    assert build_hint("82") == "○○"


def test_build_hint_never_equals_answer():
    for answer in ["1592", "H2O", "NaCl", "UTC+9", "E=mc²", "42.195", "12", "pH", "NFL"]:
        assert build_hint(answer) != answer


def test_first_syllable_hint_keeps_only_the_first_character():
    from app.game.chosung import first_syllable_hint

    assert first_syllable_hint("라면") == "라○"
    assert first_syllable_hint("김치찌개") == "김○○○"
    assert first_syllable_hint("아이스 크림") == "아○○ ○○"  # spaces kept, shape visible
    assert first_syllable_hint("서") == "서"  # a one-letter answer cannot be masked
