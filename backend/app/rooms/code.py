"""Short, human-friendly room codes.

Alphabet excludes characters that look alike (0/O, 1/I/L). 32^6 ≈ 1.07B combos.
Collision retry uses a SELECT-then-INSERT pattern (good enough for our scale)
backed by the UNIQUE index as a final safety net."""

import secrets

ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
CODE_LENGTH = 6


def generate_code() -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(CODE_LENGTH))


def is_well_formed(code: str) -> bool:
    code = code.upper()
    return len(code) == CODE_LENGTH and all(c in ALPHABET for c in code)


def normalize(code: str) -> str:
    return code.strip().upper()
