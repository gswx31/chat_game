from app.game.chosung import korean_chosung


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
