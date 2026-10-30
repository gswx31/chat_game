# ChatGame — Realtime Trivia (끄투 / 노래맞추기 스타일)

실시간 채팅으로 진행되는 멀티플레이 상식 퀴즈. 스타크래프트 유즈맵
*노래맞추기* 의 플로우를 저작권 문제를 피해 **텍스트 상식 문제**로 옮긴 게임입니다.

핵심 룰:
- 방장이 옵션 설정 (목표 점수, 라운드 시간, 카테고리, 최대 인원, 공개/비공개)
- 문제 1개 출제 → 채팅으로 **가장 먼저 정답** 친 사람 +1점
- 정답 비교는 **공백·대소문자·일부 문장부호 무시** + `accepted_answers` 대체 표기
- 라운드 절반 지나면 **자동 초성 힌트**
- 일정 인원 이상 스킵 투표 시 다음 문제로
- 누군가 **목표 점수** 도달하면 승리, 결과 화면 → **방장 리매치** 또는 로비로

접근성 (친구끼리 빠르게 모이기):
- 방마다 **6자리 코드** (영문/숫자, 헷갈리는 0/O/1/I/L 제외)
- 사인인 화면에서 **닉네임 + 방코드** 한 번에 입력하면 그대로 방까지 입장
- `/j/{CODE}` 짧은 링크 → 카톡으로 보내면 누르자마자 들어옴
- 마지막 닉네임 기억, 모바일 가로폭 대응

입장 규칙:
- **게임 중에도 방 코드로 입장·재입장 가능** (신규 입장자는 0점으로 시작, 정원 한도 안에서). 네트워크가 끊겨도 유예 시간 안에 돌아오면 자리가 유지됨.
- 방장이 강퇴하면 24시간 동안 재입장 불가.
- 빈 방은 자동 종료.
- 방장이 **리매치** 누르면 같은 방에서 다시 모집 시작 (점수 0부터, 입장 다시 가능).

## 모노레포 구조

```
chatGame/
├── backend/      FastAPI + SQLAlchemy(async) + Redis + Alembic
├── web/          React + Vite + TS
├── mobile/       기존 Flutter 코드 (백엔드 완성 후 마이그레이션 예정)
├── shared/       (예약)
├── docker-compose.yml   Postgres + Redis (개발용)
└── README.md
```

## MVP 진행 상태

| 영역 | 상태 |
|---|---|
| 모노레포 구조 정리 | ✅ |
| Postgres + Redis (compose) | ✅ |
| FastAPI 부트, JWT 게스트 로그인, 방 CRUD | ✅ |
| 문제 401문항 (8 카테고리) — `seed_data.py` 가 단일 출처, 배포 때 자동 동기화 | ✅ |
| 방 코드 + 공개/비공개 + by-code 입장 + /j/CODE | ✅ |
| WebSocket 게임 엔진 (서버 타이머, 첫정답 Redis 락, 점수, 힌트, 스킵) | ✅ |
| 결과 화면 + 리매치 | ✅ |
| 빈방 자동 종료 | ✅ |
| Alembic 마이그레이션 (`create_all` 폐기) | ✅ |
| 모바일 가로폭 대응 | ✅ |
| Redis pub/sub fanout (다중 워커) | ⏳ |
| Flutter 모바일 신규 백엔드 연동 (코드·빌드 완료, 실기기 검증 전) | ✅ |
| 소셜 로그인 (Google/Kakao) | ⏳ |

## 로컬 실행

### 0. 필요한 것

- Docker Desktop
- Python 3.12+
- Node.js 20+

### 1. 인프라

```powershell
docker compose up -d
```

### 2. 백엔드

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -e ".[dev]"
copy .env.example .env

# 스키마 적용 (Alembic, 첫 실행 + 변경 시마다)
alembic upgrade head

# 문제 동기화 (app/questions/seed_data.py 와 DB를 똑같이 맞춤. 몇 번 실행해도 안전)
python -m scripts.sync_questions

# 서버 실행
uvicorn app.main:app --reload --port 8000
```

API docs: <http://localhost:8000/docs>

### 3. 웹

```powershell
cd web
npm install
npm run dev
```

브라우저: <http://localhost:5173>

### 4. 친구 흐름 테스트

1. 브라우저 창 A: 닉네임 입력 → 방 만들기 → 방 화면에 뜬 코드(예: `ABCD42`) 또는 "링크 복사"
2. 브라우저 창 B (시크릿 창): 받은 링크(`/j/ABCD42`) 열거나, 사인인 화면 방코드 칸에 코드 입력
3. 창 A에서 "게임 시작" → 채팅창에 정답 입력 시작
4. 누군가 목표 점수 도달 → 결과 모달 → 방장이 "리매치" 또는 다같이 로비로

## WebSocket 메시지

`backend/app/ws/protocol.py` 참고.

- 클라 → 서버: `chat`, `start_game` (방장), `skip`, `rematch` (방장, 종료 후)
- 서버 → 클라: `room_state`, `player_join/leave`, `chat`, `game_start`, `round_start`, `hint`, `correct`, `round_end`, `score_update`, `skip_progress`, `game_over`, `error`
- 닫기 코드: `4404` 방 없음, `4413` 방 만석, `4423` 시작된 게임 (sealed)

## 데이터 모델 요약

- `users` — 게스트 닉네임 (+ 추후 소셜)
- `rooms` — 방 설정 + `code` (UNIQUE 6자) + `is_public` + `status` (`waiting`/`playing`/`ended`)
- `room_members` — 방별 점수
- `questions` — `answer_normalized` + `accepted_answers[]` 로 관용적 정답 매칭, `difficulty 1~5`, `category` 태그

## Redis 키

- `room:{id}:answered:{round}` — 첫 정답 락 (`SET NX EX`)
- `room:{id}:state` — Hash 라운드 스냅샷 (다중 워커 대비)
- `room:{id}:scores` — ZSet 점수 미러
