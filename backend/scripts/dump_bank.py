"""Print question-bank modules as a compact numbered list (for human / reviewer reading).

    python -X utf8 -m scripts.dump_bank science animals
"""

from __future__ import annotations

import sys
from importlib import import_module

from app.questions import bank

_LABEL = {1: "하", 2: "중", 3: "상"}


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    for name in argv:
        items = import_module(f"{bank.__name__}.{name}").ITEMS
        print(f"##### {name} ({len(items)})")
        for i, it in enumerate(items, 1):
            accepted = " | ".join(it.get("accepted", []))
            hint = f"  [힌트:{it['hint']}]" if it.get("hint") else ""
            print(
                f"{name}:{i:03d} [{_LABEL[it['difficulty']]}] {it['prompt']}  =>  {it['answer']}"
                + (f"   (인정: {accepted})" if accepted else "")
                + hint
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
