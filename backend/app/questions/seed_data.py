"""Hand-curated MVP seed. Replace/extend later via admin tooling.

Schema per item:
  prompt: the question text
  answer: canonical answer (display form)
  accepted: list of alternate spellings/synonyms (optional)
  category: one of CATEGORIES
  difficulty: 1 (easy) .. 5 (hard)
  hint: optional short hint shown when timer is low
"""

CATEGORIES = ["일반상식", "역사", "과학", "지리", "문학", "예술", "스포츠", "IT"]

SEED: list[dict] = [
    {"prompt": "대한민국의 수도는?", "answer": "서울", "category": "지리", "difficulty": 1},
    {"prompt": "한글을 창제한 조선의 왕은?", "answer": "세종대왕",
     "accepted": ["세종"], "category": "역사", "difficulty": 1},
    {"prompt": "지구에서 가장 큰 바다는?", "answer": "태평양",
     "category": "지리", "difficulty": 1, "hint": "ㅌㅍㅇ"},
    {"prompt": "물의 화학식은?", "answer": "H2O",
     "accepted": ["h2o", "에이치투오"], "category": "과학", "difficulty": 1},
    {"prompt": "현재 살아있는 가장 큰 동물은?", "answer": "흰긴수염고래",
     "accepted": ["대왕고래", "흰수염고래"], "category": "과학", "difficulty": 2},
    {"prompt": "태양계에서 가장 큰 행성은?", "answer": "목성", "category": "과학", "difficulty": 2},
    {"prompt": "1392년에 조선을 건국한 인물은?", "answer": "이성계",
     "accepted": ["태조"], "category": "역사", "difficulty": 2},
    {"prompt": "'햄릿'을 쓴 영국의 극작가는?", "answer": "셰익스피어",
     "accepted": ["윌리엄셰익스피어", "shakespeare"], "category": "문학", "difficulty": 2},
    {"prompt": "월드컵을 주관하는 국제 축구 단체의 약자는?", "answer": "FIFA",
     "accepted": ["피파", "fifa"], "category": "스포츠", "difficulty": 1},
    {"prompt": "리눅스 커널을 처음 개발한 사람은?", "answer": "리누스토르발스",
     "accepted": ["linustorvalds", "torvalds"], "category": "IT", "difficulty": 3},
    {"prompt": "원주율 π를 소수점 둘째 자리까지 쓰면?", "answer": "3.14",
     "category": "과학", "difficulty": 1},
    {"prompt": "대한민국에서 가장 높은 산은?", "answer": "한라산", "category": "지리", "difficulty": 1},
    {"prompt": "임진왜란이 일어난 해는?", "answer": "1592", "category": "역사", "difficulty": 2},
    {"prompt": "'모나리자'를 그린 화가는?", "answer": "레오나르도다빈치",
     "accepted": ["다빈치", "leonardodavinci"], "category": "예술", "difficulty": 1},
    {"prompt": "HTTP의 기본 포트 번호는?", "answer": "80", "category": "IT", "difficulty": 2},
    {"prompt": "DNA의 이중나선 구조를 밝힌 두 사람은? (성만, 알파벳순)",
     "answer": "왓슨크릭", "accepted": ["watsoncrick"], "category": "과학", "difficulty": 4},
    {"prompt": "올림픽 오륜기의 색 다섯 가지는?", "answer": "파랑노랑검정초록빨강",
     "accepted": ["청황흑록적"], "category": "스포츠", "difficulty": 3},
    {"prompt": "셰익스피어의 4대 비극 중 덴마크 왕자 이야기는?", "answer": "햄릿",
     "category": "문학", "difficulty": 2},
    {"prompt": "한국 최초의 노벨문학상 수상자는?", "answer": "한강", "category": "문학", "difficulty": 2},
    {"prompt": "프랑스의 수도는?", "answer": "파리", "accepted": ["paris"],
     "category": "지리", "difficulty": 1},
]
