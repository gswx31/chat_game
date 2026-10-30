import { useCallback, useEffect, useRef, useState } from "react";
import { roomsApi, type RoomDetail } from "../../api/client";
import { useAuth } from "../../store/auth";
import { playDing, primeOnFirstGesture } from "../../lib/sound";
import { soundEnabled } from "../../store/prefs";
import { describeClose, useGameSocket, type WsMessage } from "../../ws/useGameSocket";

export interface PlayerRow {
  user_id: string;
  nickname: string;
  score: number;
  online?: boolean;
}

export interface RoundState {
  round: number;
  prompt: string;
  category: string;
  difficulty: number;
  deadline_ts: number;
  hint?: string;
  ended?: { reason: "correct" | "timeout" | "skipped"; answer: string; nickname?: string };
}

export interface ChatRow {
  id: number;
  user_id?: string;
  nickname: string;
  text: string;
  kind: "chat" | "system";
  /** local receive time (ms) — shown as HH:mm under the bubble */
  ts: number;
}

export type RoomStatus = "waiting" | "playing" | "ended";

/** The log keeps the newest rows only (older ones are dropped, the page must stay light). */
const MAX_CHAT_ROWS = 300;

/**
 * All state of one room, fed by the room WebSocket. The lobby, game and result screens are
 * pure views over this.
 */
export function useRoom(roomId: string | undefined) {
  const { user, token } = useAuth();

  const [room, setRoom] = useState<RoomDetail | null>(null);
  const [status, setStatus] = useState<RoomStatus>("waiting");
  const [ownerId, setOwnerId] = useState<string | null>(null);
  const [winScore, setWinScore] = useState(20);
  const [roundSeconds, setRoundSeconds] = useState(30);
  const [roomName, setRoomName] = useState("");
  const [roomCode, setRoomCode] = useState("");
  const [players, setPlayers] = useState<PlayerRow[]>([]);
  const [round, setRound] = useState<RoundState | null>(null);
  const [chat, setChat] = useState<ChatRow[]>([]);
  const [skipState, setSkipState] = useState<{ votes: number; needed: number } | null>(null);
  const [finalResult, setFinalResult] = useState<{ scores: PlayerRow[]; winner_id: string | null } | null>(null);
  const [synced, setSynced] = useState(false); // got the first room_state snapshot

  const chatSeq = useRef(0);

  // Web Audio, not new Audio(): on iPhone an <audio> element stops the player's own music.
  useEffect(() => primeOnFirstGesture(), []);

  useEffect(() => {
    if (!roomId) return;
    roomsApi
      .get(roomId)
      .then((r) => {
        setRoom(r);
        setRoomName((n) => n || r.name);
        setRoomCode((c) => c || r.code);
        setWinScore((w) => w || r.win_score);
        setRoundSeconds((s) => s || r.round_seconds);
      })
      .catch(() => setRoom(null));
  }, [roomId]);

  const pushChat = useCallback((row: Omit<ChatRow, "id" | "ts">) => {
    chatSeq.current += 1;
    const full: ChatRow = { ...row, id: chatSeq.current, ts: Date.now() };
    setChat((prev) => [...prev.slice(1 - MAX_CHAT_ROWS), full]);
  }, []);
  const system = useCallback((text: string) => pushChat({ nickname: "system", text, kind: "system" }), [pushChat]);

  // Every frame is handled in order (see useGameSocket). Only setters/refs are used inside,
  // so this closure never goes stale.
  const handleMessage = (m: WsMessage) => {
    switch (m.type) {
      case "room_state": {
        const next = m.status as RoomStatus;
        setSynced(true);
        setStatus(next);
        setOwnerId((m.owner_id as string) ?? null);
        setWinScore((m.win_score as number) ?? 20);
        if (typeof m.round_seconds === "number") setRoundSeconds(m.round_seconds);
        if (typeof m.room_name === "string" && m.room_name) setRoomName(m.room_name);
        if (typeof m.room_code === "string" && m.room_code) setRoomCode(m.room_code);
        setPlayers((m.players as PlayerRow[]) ?? []);
        if (m.current) {
          const c = m.current as Record<string, unknown>;
          setRound({
            round: c.round as number,
            prompt: String(c.prompt),
            category: String(c.category),
            difficulty: c.difficulty as number,
            deadline_ts: c.deadline_ts as number,
            hint: typeof c.hint === "string" ? c.hint : undefined, // restored after a reconnect
          });
        } else setRound(null);
        if (next === "waiting") {
          setFinalResult(null);
          setSkipState(null);
        }
        break;
      }
      case "player_join": {
        // The server announces a join but does not resend the scoreboard, so add the
        // player here — otherwise the owner never sees who has come in.
        const id = String(m.user_id);
        const nick = String(m.nickname);
        setPlayers((prev) =>
          prev.some((p) => p.user_id === id)
            ? prev.map((p) => (p.user_id === id ? { ...p, nickname: nick, online: true } : p))
            : [...prev, { user_id: id, nickname: nick, score: 0, online: true }]
        );
        system(`${nick}님이 입장했어요`);
        break;
      }
      case "player_leave": {
        // The server only sends this once the player is really gone (during a game it waits
        // out a 20 s reconnect grace first), so the player is removed — same as the app.
        const id = String(m.user_id);
        setPlayers((prev) => prev.filter((p) => p.user_id !== id));
        system(`${m.nickname}님이 나갔어요`);
        break;
      }
      case "chat":
        pushChat({ user_id: String(m.user_id), nickname: String(m.nickname), text: String(m.text), kind: "chat" });
        break;
      case "game_start":
        setStatus("playing");
        setFinalResult(null);
        system("🎮 게임 시작!");
        break;
      case "round_start":
        setRound({
          round: m.round as number,
          prompt: String(m.prompt),
          category: String(m.category),
          difficulty: m.difficulty as number,
          deadline_ts: m.deadline_ts as number,
        });
        setSkipState(null);
        system(`라운드 ${m.round} 시작!`);
        break;
      case "hint":
        setRound((r) => (r ? { ...r, hint: String(m.hint) } : r));
        system(`💡 힌트: ${m.hint}`);
        break;
      case "skip_progress":
        setSkipState({ votes: m.votes as number, needed: m.needed as number });
        system(`⏭️ 스킵 투표 ${m.votes}/${m.needed}`);
        break;
      case "correct":
        setRound((r) =>
          r ? { ...r, ended: { reason: "correct", answer: String(m.answer), nickname: String(m.nickname) } } : r
        );
        system(`✅ ${m.nickname}님 정답! (${m.answer})`);
        if (soundEnabled()) playDing();
        break;
      case "player_kicked": {
        // No player_leave follows a kick (the server suppresses it), so drop them here.
        const id = String(m.user_id);
        setPlayers((prev) => prev.filter((p) => p.user_id !== id));
        system(`🚫 ${m.nickname}님이 강퇴되었어요`);
        break;
      }
      case "round_end":
        setRound((r) =>
          r ? { ...r, ended: { reason: m.reason as "timeout" | "skipped", answer: String(m.answer) } } : r
        );
        system(m.reason === "skipped" ? `⏭️ 스킵됨 (정답: ${m.answer})` : `⌛ 시간 초과 (정답: ${m.answer})`);
        break;
      case "score_update":
        setPlayers((m.scores as PlayerRow[]) ?? []);
        break;
      case "game_over":
        setStatus("ended");
        setFinalResult({ scores: (m.scores as PlayerRow[]) ?? [], winner_id: (m.winner_id as string) ?? null });
        break;
      case "error":
        system(`⚠️ ${m.message}`);
        break;
    }
  };

  const { connected, closeInfo, send } = useGameSocket(roomId, token, handleMessage);

  const isOwner = !!user && ownerId === user.user_id;

  return {
    user,
    room,
    roomName: roomName || room?.name || "",
    roomCode: roomCode || room?.code || "",
    status,
    ownerId,
    isOwner,
    winScore,
    roundSeconds,
    players,
    /** players that count as present: the server also lists people who left ("(나감)") as long as they hold points */
    livePlayers: players.filter((p) => p.online !== false),
    round,
    chat,
    skipState,
    finalResult,
    synced,
    connected,
    closeMsg: describeClose(closeInfo),
    // actions
    sendChat: (text: string) => send({ type: "chat", text }),
    startGame: () => send({ type: "start_game" }),
    skip: () => send({ type: "skip" }),
    rematch: () => send({ type: "rematch" }),
    kick: (userId: string) => send({ type: "kick", target_user_id: userId }),
  };
}

export type RoomApi = ReturnType<typeof useRoom>;
