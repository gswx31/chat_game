"""IT 문제 (실제 한국 상식퀴즈 씨앗을 최소 변환하고 사실·게임성 검수를 거침)."""

from app.questions.bank._base import maker, 중, 하

ask = maker("IT")

ITEMS = [
    ask(하, "인터넷(Internet)과 시민(Citizen)을 합쳐 만든 말은?", "네티즌", "netizen"),
    ask(
        중,
        "애플 컴퓨터 '맥'은 사과 품종 이름에서 따온 어떤 이름의 줄임말일까?",
        "매킨토시",
        "맥킨토시",
        "매킨토쉬",
        "맥킨토쉬",
        "macintosh",
        "mcintosh",
    ),
]
