"""WebSocket entry: presence + chat + answer detection + skip + start_game.

Room join rules:
- ``waiting``: anyone with the code can connect (subject to max_players)
- ``playing``: returning players always allowed; new players also allowed up to
  max_players — they join with score 0
- ``ended``: same as playing; useful for viewing final scores / waiting for rematch
- kicked users are refused until their ban expires
The REST endpoint ``GET /rooms/by-code/{code}`` returns status so the client
can display an informational banner (e.g. "게임 진행중 — 참여하시겠습니까?")
before connecting.

Capacity is measured against *live* occupancy (``engine.players``, which holds a
slot through the disconnect grace window), not ``RoomMember`` rows. Those rows
are an append-only score ledger — counting them meant a room that thirty people
had ever passed through was full forever.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.core.security import decode_token
from app.db.models import Room, RoomMember, User
from app.db.session import SessionLocal
from app.game import registry
from app.game.engine import RoomConfig, is_skip_command
from app.safety.blocks import blocks
from app.safety.suspension import is_suspended
from app.ws import protocol as P
from app.ws.manager import manager

router = APIRouter()

log = logging.getLogger(__name__)

# Custom close codes (4xxx range reserved for app)
WS_CLOSE_UNAUTHORIZED = 4401  # bad/expired token
WS_CLOSE_ROOM_NOT_FOUND = 4404
WS_CLOSE_KICKED = 4403  # owner kicked you
WS_CLOSE_ROOM_FULL = 4413
WS_CLOSE_ROOM_SEALED = 4423  # game already started — no entry
WS_CLOSE_SUSPENDED = 4430  # an operator suspended the account after reports


async def _reject(websocket: WebSocket, code: int, reason: str) -> None:
    """Accept the socket, then close it with an app close code.

    Closing *before* accept rejects the HTTP handshake, which Dart and browser
    clients surface as a bare connection error with no close code — they can't
    tell "you were kicked" from "the train went into a tunnel" and retry forever.
    Accepting first costs nothing and gives the client something to act on.
    """
    try:
        await websocket.accept()
        await websocket.close(code=code, reason=reason)
    except Exception:  # noqa: BLE001 — client may already be gone
        pass


@router.websocket("/rooms/{room_id}")
async def room_socket(
    websocket: WebSocket,
    room_id: str,
    token: str = Query(...),
) -> None:
    try:
        payload = decode_token(token)
    except Exception:
        await _reject(websocket, WS_CLOSE_UNAUTHORIZED, "invalid token")
        return

    user_id: str = payload.get("sub", "")
    nickname: str = payload.get("nickname", "익명")
    if not user_id:
        await _reject(websocket, WS_CLOSE_UNAUTHORIZED, "invalid token")
        return

    async with SessionLocal() as db:
        room = await db.get(Room, room_id)
        if not room:
            await _reject(websocket, WS_CLOSE_ROOM_NOT_FOUND, "room not found")
            return

        # Bump last_active_at on every connect so idle-room cleanup leaves
        # rooms that people are actually opening alone.
        room.last_active_at = datetime.now(UTC)
        max_players = room.max_players
        await db.commit()
        user = await db.get(User, user_id)
        if user and user.nickname:
            nickname = user.nickname
        suspended = is_suspended(user)

        cfg = RoomConfig(
            win_score=room.win_score,
            round_seconds=room.round_seconds,
            categories=room.categories or [],
            difficulty_min=room.difficulty_min,
            difficulty_max=room.difficulty_max,
            owner_id=room.owner_id,
            question_set_id=room.question_set_id,
            room_name=room.name,
            room_code=room.code,
        )

    if suspended:
        await _reject(websocket, WS_CLOSE_SUSPENDED, "suspended")
        return

    engine = await registry.get_or_create(room_id, lambda: cfg, manager.broadcast)

    if await engine.is_banned(user_id):
        await _reject(websocket, WS_CLOSE_KICKED, "kicked")
        return

    # Live occupancy: someone already holding a slot (connected, or inside the
    # grace window) always gets back in; everyone else counts against the cap.
    if user_id not in engine.players and len(engine.players) >= max_players:
        await _reject(websocket, WS_CLOSE_ROOM_FULL, "room full")
        return

    # Score ledger row — created on first entry, never removed, never counted.
    async with SessionLocal() as db:
        already = await db.scalar(
            select(RoomMember.id).where(
                RoomMember.room_id == room_id, RoomMember.user_id == user_id
            )
        )
        if not already:
            db.add(RoomMember(room_id=room_id, user_id=user_id))
            await db.commit()
        await blocks.load(db, user_id)

    is_grace = engine.is_in_grace(user_id)
    engine.cancel_grace(user_id)
    engine.register_player(user_id, nickname)
    await manager.connect(room_id, user_id, websocket)
    await websocket.send_json(engine.snapshot())
    if not is_grace:
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
                    # Whoever blocked the sender doesn't get the line.
                    skip_if=lambda recipient: blocks.blocks(recipient, user_id),
                )
                if is_skip_command(text):
                    # Not an answer: a vote to skip (ignored outside a running question).
                    await engine.vote_skip(user_id)
                    continue
                await engine.submit_chat(user_id, text)
            elif kind == P.C_START:
                if engine.status != "waiting":
                    await websocket.send_json(
                        {"type": P.S_ERROR, "message": "이미 진행중이거나 종료됐어요"}
                    )
                    continue
                # Flip DB status synchronously so a parallel REST GET reflects it.
                # Re-query owner_id from DB so ownership changes (future feature) are reflected.
                async with SessionLocal() as db:
                    row = await db.get(Room, room_id)
                    if not row or row.owner_id != user_id:
                        await websocket.send_json(
                            {"type": P.S_ERROR, "message": "방장만 시작할 수 있어요"}
                        )
                        continue
                    row.status = "playing"
                    row.last_active_at = datetime.now(UTC)
                    await db.commit()
                await engine.start()
            elif kind == P.C_SKIP:
                await engine.vote_skip(user_id)
            elif kind == P.C_KICK:
                target = str(data.get("target_user_id", ""))
                async with SessionLocal() as db:
                    row = await db.get(Room, room_id)
                    is_owner = row is not None and row.owner_id == user_id
                if not is_owner:
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
                # Bar them from reconnecting — their client retries in ~1s.
                await engine.ban(target)
                log.info(
                    "kick room=%s owner=%s target=%s", room_id, user_id, target
                )
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
        if engine.status == "playing" and user_id not in engine.recent_kicks:
            # Grant a 20-second grace window so brief app switches don't eject
            # the player — the grace task broadcasts player_leave if they don't return.
            engine.start_grace(user_id, nickname)
        else:
            engine.unregister_player(user_id)
            if user_id in engine.recent_kicks:
                engine.recent_kicks.discard(user_id)
            else:
                await manager.broadcast(
                    room_id,
                    {"type": P.S_PLAYER_LEAVE, "user_id": user_id, "nickname": nickname},
                )
        await registry.drop_if_empty(room_id)
