import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.auth.router import router as auth_router
from app.core.config import settings
from app.db.session import close_engine
from app.question_sets.router import router as question_sets_router
from app.questions.router import router as questions_router
from app.redis_client import close_redis, init_redis
from app.rooms.cleanup import cleanup_idle_rooms
from app.rooms.router import router as rooms_router
from app.ws.router import router as ws_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    await init_redis()
    cleanup_task = asyncio.create_task(cleanup_idle_rooms(), name="idle-room-cleanup")
    try:
        yield
    finally:
        cleanup_task.cancel()
        try:
            await cleanup_task
        except asyncio.CancelledError:
            pass
        await close_redis()
        await close_engine()


app = FastAPI(title="ChatGame API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(rooms_router, prefix="/rooms", tags=["rooms"])
app.include_router(questions_router, prefix="/questions", tags=["questions"])
app.include_router(question_sets_router, prefix="/question-sets", tags=["question-sets"])
app.include_router(ws_router, prefix="/ws", tags=["ws"])
