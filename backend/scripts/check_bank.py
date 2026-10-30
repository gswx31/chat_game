"""Check one question-bank module while writing it.

    python -X utf8 -m scripts.check_bank science
    python -X utf8 -m scripts.check_bank --all
"""

from __future__ import annotations

import sys
from collections import Counter
from importlib import import_module
from pkgutil import iter_modules

from app.questions import bank
from app.questions.bank._check import check_items, cross_leaks


def _module_names() -> list[str]:
    return sorted(m.name for m in iter_modules(bank.__path__) if not m.name.startswith("_"))


def _items(name: str) -> list[dict]:
    return list(import_module(f"{bank.__name__}.{name}").ITEMS)


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    names = _module_names() if argv[0] == "--all" else argv
    everything = [i for n in _module_names() for i in _items(n)]
    bad = 0
    for name in names:
        items = _items(name)
        by_diff = Counter(i["difficulty"] for i in items)
        by_cat = Counter(i["category"] for i in items)
        print(
            f"== {name}: {len(items)} items  "
            f"(하 {by_diff[1]} / 중 {by_diff[2]} / 상 {by_diff[3]})  {dict(by_cat)}"
        )
        problems = check_items(items)
        for p in problems:
            print("  PROBLEM", p)
        bad += len(problems)
        mine = {i["prompt"] for i in items}
        leaks = [(a, p) for a, p in cross_leaks(everything) if p in mine]
        for a, p in leaks[:15]:
            print(f"  note: answer {a!r} also appears in prompt [{p[:40]}]")
        if len(leaks) > 15:
            print(f"  note: ... and {len(leaks) - 15} more answer-in-other-prompt overlaps")
    print("OK" if not bad else f"{bad} problem(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
