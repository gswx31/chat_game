"""Korean 초성(chosung) extractor for hint generation."""

_INITIALS = [
    "ㄱ",
    "ㄲ",
    "ㄴ",
    "ㄷ",
    "ㄸ",
    "ㄹ",
    "ㅁ",
    "ㅂ",
    "ㅃ",
    "ㅅ",
    "ㅆ",
    "ㅇ",
    "ㅈ",
    "ㅉ",
    "ㅊ",
    "ㅋ",
    "ㅌ",
    "ㅍ",
    "ㅎ",
]

_HANGUL_BASE = 0xAC00
_HANGUL_LAST = 0xD7A3


def _is_hangul(ch: str) -> bool:
    return _HANGUL_BASE <= ord(ch) <= _HANGUL_LAST


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


_MASK = "○"
# Answers this short or shorter reveal nothing about themselves, not even a first character.
_MIN_LEN_TO_REVEAL_FIRST = 3


def build_hint(answer: str) -> str:
    """Hint shown halfway through a round when a question has no hand-written one.

    Hangul answers get their 초성. Anything else (years, formulas like ``H2O``,
    acronyms) has no 초성 -- ``korean_chosung`` would hand back the answer itself --
    so those are masked instead, keeping the first character and the shape:
    ``1592`` -> ``1○○○``, ``42.195`` -> ``4○.○○○``.
    """
    if any(_is_hangul(ch) for ch in answer):
        return korean_chosung(answer)

    maskable = [i for i, ch in enumerate(answer) if ch.isalnum()]
    if not maskable:
        # Symbols only (e.g. "@"): there is no shape worth keeping.
        return "".join(ch if ch.isspace() else _MASK for ch in answer)
    reveal = maskable[0] if len(maskable) >= _MIN_LEN_TO_REVEAL_FIRST else -1
    return "".join(
        ch if (not ch.isalnum() or i == reveal) else _MASK for i, ch in enumerate(answer)
    )


def first_syllable_hint(answer: str) -> str:
    """Hint for 초성 quizzes, where the prompt already shows the 초성: reveal the first
    syllable instead (``라면`` -> ``라○``, ``김치찌개`` -> ``김○○○``)."""
    out: list[str] = []
    seen_first = False
    for ch in answer:
        if ch.isspace():
            out.append(ch)
        elif not seen_first:
            out.append(ch)
            seen_first = True
        else:
            out.append(_MASK)
    return "".join(out)
