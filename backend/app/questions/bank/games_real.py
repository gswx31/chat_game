"""게임 문제 (실제 한국 상식퀴즈 씨앗을 최소 변환하고 사실·게임성 검수를 거침)."""

from app.questions.bank._base import maker, 중

ask = maker("게임")

ITEMS = [
    ask(
        중,
        "2000년 개국해 스타리그를 중계한 우리나라 최초의 게임 전문 방송 채널은?",
        "온게임넷",
        "OGN",
        "온겜",
        "온게임넷방송",
        "ongamenet",
    ),
]
