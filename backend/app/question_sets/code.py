"""8-character share code generator for question sets."""
import random
import string

# Exclude visually ambiguous characters
_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"


def generate_code() -> str:
    return "".join(random.choices(_CHARS, k=8))


def normalize(code: str) -> str:
    return code.strip().upper()


def is_well_formed(code: str) -> bool:
    return len(code) == 8 and all(c in _CHARS for c in code)
