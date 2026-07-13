# ChatGame Backend

FastAPI + SQLAlchemy(async) + Redis. Real-time quiz game backend.

## Run locally

### 1. Postgres + Redis

From the repo root:

```bash
docker compose up -d
```

### 2. Python env

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -e ".[dev]"
copy .env.example .env
```

### 3. Apply migrations

```powershell
alembic upgrade head
```

### 4. Seed questions

Option A — built-in 20-question seed (POST endpoint, dev only):

```powershell
uvicorn app.main:app --reload --port 8000
# in another shell:
curl -X POST http://localhost:8000/questions/seed
```

Option B — CSV import (recommended, ~75 questions across 8 categories):

```powershell
python -m scripts.import_questions scripts/questions_seed.csv
```

Or the smaller 20-row sample at `scripts/example_questions.csv`. Both are idempotent — re-running skips duplicates by `(prompt, answer_normalized)`.

### 5. Run the API

```powershell
uvicorn app.main:app --reload --port 8000
```

API docs: <http://localhost:8000/docs>

## WebSocket protocol

See `app/ws/protocol.py`. Summary:

- Connect: `GET /ws/rooms/{room_id}?token=<JWT>`
- Client sends: `chat` / `start_game` (owner) / `skip`
- Server sends: `room_state`, `player_join/leave`, `chat`, `game_start`, `round_start`, `hint`, `correct`, `round_end`, `score_update`, `skip_progress`, `game_over`, `error`

## Project layout

```
app/
  main.py              FastAPI app, lifespan, routers
  core/                config (pydantic-settings), JWT
  db/                  Base, async session, models (User/Room/RoomMember/Question)
  auth/                guest login + /me
  rooms/               room CRUD
  questions/           seed + normalize + admin endpoints
  game/
    engine.py          server-authoritative round loop (asyncio Task per room)
    registry.py        per-room engine registry
    chosung.py         Korean initial-consonant extractor (auto hint)
  ws/
    router.py          WebSocket entrypoint (auth, presence, chat/skip/start dispatch)
    manager.py         in-process connection manager
    protocol.py        message type constants
  redis_client.py      shared async Redis client
alembic/               migrations
scripts/
  import_questions.py  CSV importer
  example_questions.csv
```

## Migrations

Generate a new revision after model changes:

```powershell
alembic revision --autogenerate -m "describe change"
alembic upgrade head
```

## Next milestones

- Redis pub/sub bridge so we can run multiple uvicorn workers
- Owner transfer on disconnect
- Question authoring UI / admin endpoints
- Social auth (Google / Kakao)
