"""영어 questions. Rewritten after the independent review pass."""

from app.questions.bank._base import maker, 중, 하

ask = maker("영어")

ITEMS = [
    ask(
        하,
        "풀 죽은 친구에게 Cheer up이라고 하면 우리말로 무슨 뜻일까요?",
        "힘내",
        "힘내요",
        "힘내세요",
        "힘내라",
        "힘내자",
        "기운내",
        "기운내요",
        "기운내세요",
        "파이팅",
        "화이팅",
    ),
    ask(
        중,
        "'Congratulations'는 우리말로?",
        "축하합니다",
        "축하해",
        "축하해요",
        "축하",
        "축하드립니다",
        "축하드려요",
        "축하한다",
    ),
    ask(중, "영어 Cucumber는 어떤 채소일까요?", "오이"),
    ask(중, "'Library'는 우리말로?", "도서관"),
    ask(중, "영어로 Mosquito라고 부르는 곤충은?", "모기"),
    ask(중, "'Fireworks'는 우리말로?", "불꽃놀이", "불꽃", "폭죽"),
    ask(중, "'Delicious'는 우리말로?", "맛있는", "맛있다", "맛있어", "맛있어요", "맛있네"),
    ask(중, "'Hungry'는 우리말로?", "배고픈", "배고파", "배고프다", "배고파요", "배고픔"),
    ask(중, "영어로 Nephew는 가족 중 누구를 가리킬까요?", "조카"),
    ask(중, "'Wednesday'는 무슨 요일일까?", "수요일", "수"),
    ask(중, "'September'는 몇 월일까?", "9월", "9", "구월", "9월달"),
    ask(중, "'Autumn'은 어느 계절일까?", "가을", "가을철"),
    ask(중, "숫자 12를 영어 단어로 쓰면?", "twelve"),
    ask(중, "숫자 100을 영어 단어로 쓰면?", "hundred", "onehundred", "ahundred"),
    ask(하, "TV는 어떤 영어 단어의 줄임말일까?", "television", "텔레비전", "텔레비젼"),
    ask(중, "PC는 Personal 뒤에 어떤 영어 단어가 붙은 줄임말일까?", "computer", "컴퓨터"),
    ask(
        중,
        "SNS는 Social Network 뒤에 어떤 영어 단어가 붙은 줄임말일까?",
        "service",
        "services",
        "서비스",
    ),
    ask(
        중,
        "기업의 CEO를 우리말 다섯 글자로 하면?",
        "최고경영자",
        "사장",
        "대표",
        "대표이사",
        "경영자",
    ),
    ask(
        중, "VIP는 Very와 Person 사이에 어떤 영어 단어가 들어간 줄임말일까?", "important", "중요한"
    ),
    ask(하, "시각 앞에 붙는 AM과 PM 중 PM은 우리말로 무엇일까?", "오후"),
]
