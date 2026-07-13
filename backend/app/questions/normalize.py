import re

_SPACE_RE = re.compile(r"\s+")
_PUNCT_RE = re.compile(r"[.,!?'\"·~`\-_/\\()\[\]{}<>:;]")


def normalize_answer(text: str) -> str:
    """Lowercase, remove whitespace and common punctuation for forgiving matching."""
    s = text.strip().lower()
    s = _PUNCT_RE.sub("", s)
    s = _SPACE_RE.sub("", s)
    return s
