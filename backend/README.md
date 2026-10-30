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

Option A — one command (recommended). `app/questions/seed_data.py` is the single source of truth;
this makes the table match it exactly (add / update / delete) and is safe to re-run:

```powershell
python -m scripts.sync_questions            # add --dry-run to preview
```

Option B — the same thing over HTTP (dev only; returns 404 when `APP_ENV=production`):

```powershell
uvicorn app.main:app --reload --port 8000
# in another shell:
curl -X POST http://localhost:8000/questions/seed
```

Option C — import your own CSV (adds only; does not remove anything):

```powershell
python -m scripts.import_questions scripts/example_questions.csv
```

Idempotent — re-running skips duplicates by `(prompt, answer_normalized)`.

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

## Reports, blocks and suspensions

Google Play asks chat apps for an in-app way to report and block players and for the operator
to act on reports. `app/safety/`:

- `POST /safety/reports` — reason (`abuse|sexual|spam|cheat|other`), optional detail, the chat
  line and the room code. The same player + reason + line within an hour is not stored twice;
  20 reports per reporter per day.
- `GET /safety/blocks`, `PUT|DELETE /safety/blocks/{user_id}` — a blocker no longer receives the
  blocked player's `chat` frames. The filter is server side (`RoomManager.broadcast(skip_if=)`),
  so old clients get it too. The block sets live in memory (`app/safety/blocks.py`), like the
  rest of the room state: single process only.
- Chat is not stored; a report keeps only the line the reporter attached.
- Operator, on the server (inside the backend container when deployed):

  ```powershell
  python -m scripts.moderation list              # open reports grouped by reported player
  python -m scripts.moderation suspend USER_ID 3 # 3 days; their open reports become "actioned"
  python -m scripts.moderation unsuspend USER_ID
  python -m scripts.moderation dismiss 12 13     # close reports without acting
  ```

  A suspended account gets 403 from `/auth/guest` and WebSocket close code `4430`. A guest can
  get around it by clearing the app's data (new device id), so this is a speed bump, not a ban.

## Project layout

```
app/
  main.py              FastAPI app, lifespan, routers
  core/                config (pydantic-settings), JWT
  db/                  Base, async session, models (User/Room/RoomMember/Question/Report/UserBlock)
  auth/                guest login + /me
  rooms/               room CRUD
  safety/              report / block / suspension
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
  sync_questions.py    make the questions table match app/questions/seed_data.py
  moderation.py        list reports, suspend / unsuspend players
  import_questions.py  CSV importer (adds only)
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
