"""영어 문제 (실제 한국 상식퀴즈 씨앗을 최소 변환하고 사실·게임성 검수를 거침)."""

from app.questions.bank._base import maker, 하

ask = maker("영어")

ITEMS = [
    ask(
        하,
        "영어 단어 nuclear의 우리말 뜻은?",
        "핵",
        "핵의",
        "원자핵",
        "원자핵의",
        "원자력",
        "원자력의",
    ),
]
