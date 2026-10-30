"""The question bank: one module per topic, each exporting ``ITEMS``.

Authoring rules and the automatic checks live in ``_check.py`` (run
``python -m scripts.check_bank <module>`` while writing a module).
"""

# Order = how categories are listed in the app.
CATEGORIES = [
    "일반상식",
    "한국사",
    "세계사",
    "과학",
    "사회",
    "지리",
    "스포츠",
    "속담·사자성어",
    "국어",
    "초성퀴즈",
    "넌센스",
    "음식",
    "동물",
    "영어",
    "대중문화",
    "연예인",
    "게임",
    "예술",
    "IT",
]
