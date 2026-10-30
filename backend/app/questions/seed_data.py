"""System quiz questions = every module in ``app.questions.bank``.

This is the single source of truth. Deploys run ``python -m scripts.sync_questions``, which
makes the DB table identical to ``SEED`` (add / update / delete). To change a question, edit
its module in ``bank/`` and run ``pytest tests/test_seed_data.py``.

The bar for a question ("대중적 상식"): most Korean adults know it or say "아, 그거!" at once.
Short, punchy and fun -- in the spirit of the 스타크래프트 유즈맵 상식퀴즈 -- never a pub-quiz
stumper.

Answer matching is exact after ``normalize_answer`` (lowercase, whitespace and
``. , ! ? ' " · ~ ` - _ / \\ ( ) [ ] { } < > : ;`` removed). ``= + % ²`` and units (년·명·km)
are NOT removed, so list natural variants in ``accepted`` (and "1592년" for year answers).
"""

from __future__ import annotations

from importlib import import_module
from pkgutil import iter_modules

from app.questions import bank

CATEGORIES = bank.CATEGORIES


def _load() -> list[dict]:
    items: list[dict] = []
    for info in sorted(iter_modules(bank.__path__), key=lambda m: m.name):
        if info.name.startswith("_"):
            continue
        items.extend(import_module(f"{bank.__name__}.{info.name}").ITEMS)
    order = {name: index for index, name in enumerate(CATEGORIES)}
    items.sort(key=lambda item: order.get(item["category"], len(order)))  # stable
    return items


SEED: list[dict] = _load()
