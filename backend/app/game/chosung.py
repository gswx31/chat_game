"""Korean 초성(chosung) extractor for hint generation."""

_INITIALS = [
    "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
    "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
]

_HANGUL_BASE = 0xAC00
_HANGUL_LAST = 0xD7A3


def korean_chosung(text: str) -> str:
    out: list[str] = []
    for ch in text:
        code = ord(ch)
        if _HANGUL_BASE <= code <= _HANGUL_LAST:
            idx = (code - _HANGUL_BASE) // (21 * 28)
            out.append(_INITIALS[idx])
        else:
            out.append(ch)
    return "".join(out)
