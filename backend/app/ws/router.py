"""WebSocket entry: presence + chat + answer detection + skip + start_game.

Room join rules:
- ``waiting``: anyone with the code can connect (subject to max_players)
- ``playing``: returning members (already in RoomMember) always allowed;
  new members also allowed up to max_players — they join with score 0
- ``ended``: same as playing; useful for viewing final scores / waiting for rematch
The REST endpoint ``GET /rooms/by-code/{code}`` returns status so the client
can display an informational banner (e.g. "게임 진행중 — 참여하시겠습니까?")
before connecting.
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy import func, select

from app.core.security import decode_token
from app.db.models import Room, RoomMember, User
from app.db.session import SessionLocal
from app.game import registry
from app.game.engine import RoomConfig
from app.ws import protocol as P
from app.ws.manager import manager

router = APIRouter()

# Custom close codes (4xxx range reserved for app)
WS_CLOSE_ROOM_NOT_FOUND = 4404
WS_CLOSE_KICKED = 4403  # owner kicked you
WS_CLOSE_ROOM_FULL = 4413
WS_CLOSE_ROOM_SEALED = 4423  # game already started — no entry


@router.websocket("/rooms/{room_id}")
async def room_socket(
    websocket: WebSocket,
    room_id: str,
    token: str = Query(...),
) -> None:
    try:
        payload = decode_token(token)
    except Exception:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    user_id: str = payload.get("sub", "")
    nickname: str = payload.get("nickname", "익명")
    if not user_id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    async with SessionLocal() as db:
        room = await db.get(Room, room_id)
        if not room:
            await websocket.close(code=WS_CLOSE_ROOM_NOT_FOUND, reason="room not found")
            return

        is_member = await db.scalar(
            select(RoomMember).where(
                RoomMember.room_id == room_id, RoomMember.user_id == user_id
            )
        )
        if not is_member:
            count = await db.scalar(
                select(func.count(RoomMember.id)).where(RoomMember.room_id == room_id)
            )
            if (count or 0) >= room.max_players:
                await websocket.close(code=WS_CLOSE_ROOM_FULL, reason="room full")
                return
            db.add(RoomMember(room_id=room_id, user_id=user_id))
        # Bump last_active_at on every connect so idle-room cleanup leaves
        # rooms that people are actually opening alone.
        room.last_active_at = datetime.now(UTC)
        await db.commit()
        user = await db.get(User, user_id)
        if user and user.nickname:
            nickname = user.nickname

        cfg = RoomConfig(
            win_score=room.win_score,
            round_seconds=room.round_seconds,
            categories=room.categories or [],
            difficulty_min=room.difficulty_min,
            difficulty_max=room.difficulty_max,
            owner_id=room.owner_id,
            question_set_id=room.question_set_id,
        )

    engine = await registry.get_or_create(room_id, lambda: cfg, manager.broadcast)
    engine.register_player(user_id, nickname)
    await manager.connect(room_id, user_id, websocket)
    await websocket.send_json(engine.snapshot())
    await manager.broadcast(
        room_id,
        {"type": P.S_PLAYER_JOIN, "user_id": user_id, "nickname": nickname},
    )

    try:
        while True:
            data = await websocket.receive_json()
            kind = data.get("type")
            if kind == P.C_CHAT:
                text = str(data.get("text", ""))[:300]
                if not text.strip():
                    continue
                # Broadcast the chat FIRST so every client's log shows the
                # message before the engine's `correct` / `round_end` event,
                # even when this message is the winning answer.
                await manager.broadcast(
                    room_id,
                    {
                        "type": P.S_CHAT,
                        "user_id": user_id,
                        "nickname": nickname,
                        "text": text,
                    },
                )
                await engine.submit_chat(user_id, text)
            elif kind == P.C_START:
                if cfg.owner_id != user_id:
                    await websocket.send_json(
                        {"type": P.S_ERROR, "message": "방장만 시작할 수 있어요"}
                    )
                    continue
                if engine.status != "waiting":
                    await websocket.send_json(
                        {"type": P.S_ERROR, "message": "이미 진행중이거나 종료됐어요"}
                    )
                    continue
                # Flip DB status synchronously so a parallel REST GET reflects it.
                async with SessionLocal() as db:
                    row = await db.get(Room, room_id)
                    if row:
                        row.status = "playing"
                        row.last_active_at = datetime.now(UTC)
                        await db.commit()
                await engine.start()
            elif kind == P.C_SKIP:
                await engine.vote_skip(user_id)
            elif kind == P.C_KICK:
                target = str(data.get("target_user_id", ""))
                if cfg.owner_id != user_id:
                    await websocket.send_json(
                        {"type": P.S_ERROR, "message": "방장만 강퇴할 수 있어요"}
                    )
                    continue
                if engine.status != "waiting":
                    await websocket.send_json(
                        {"type": P.S_ERROR, "message": "게임 시작 전에만 강퇴할 수 있어요"}
                    )
                    continue
                if not target or target == user_id or target not in engine.players:
                    await websocket.send_json(
                        {"type": P.S_ERROR, "message": "강퇴할 대상이 없어요"}
                    )
                    continue
                target_nick = engine.players.get(target, "?")
                # Mark before broadcast so the WS finally block can suppress
                # the redundant player_leave for this user.
                engine.recent_kicks.add(target)
                await manager.broadcast(
                    room_id,
                    {
                        "type": P.S_PLAYER_KICKED,
                        "user_id": target,
                        "nickname": target_nick,
                    },
                )
                await manager.close_one(
                    room_id, target, code=WS_CLOSE_KICKED, reason="kicked"
                )
            elif kind == P.C_REMATCH:
                if cfg.owner_id != user_id:
                    await websocket.send_json(
                        {"type": P.S_ERROR, "message": "방장만 리매치할 수 있어요"}
                    )
                    continue
                if engine.status != "ended":
                    await websocket.send_json(
                        {"type": P.S_ERROR, "message": "끝난 게임에서만 리매치할 수 있어요"}
                    )
                    continue
                ok = await engine.reset_for_rematch()
                if not ok:
                    continue
                async with SessionLocal() as db:
                    row = await db.get(Room, room_id)
                    if row:
                        row.status = "waiting"
                        row.ended_at = None
                        row.last_active_at = datetime.now(UTC)
                        await db.commit()
                await manager.broadcast(room_id, engine.snapshot())
    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(room_id, user_id)
        engine.unregister_player(user_id)
        # Skip the player_leave broadcast if this disconnect was a kick — the
        # owner's kick already triggered a player_kicked event.
        if user_id in engine.recent_kicks:
            engine.recent_kicks.discard(user_id)
        else:
            await manager.broadcast(
                room_id,
                {"type": P.S_PLAYER_LEAVE, "user_id": user_id, "nickname": nickname},
            )
        await registry.drop_if_empty(room_id)
