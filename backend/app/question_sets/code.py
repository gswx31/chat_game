"""8-character share code generator for question sets."""
import secrets

# Exclude visually ambiguous characters
_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"


def generate_code() -> str:
    return "".join(secrets.choice(_CHARS) for _ in range(8))


def normalize(code: str) -> str:
    return code.strip().upper()


def is_well_formed(code: str) -> bool:
    return len(code) == 8 and all(c in _CHARS for c in code)
