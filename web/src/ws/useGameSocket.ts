import { useEffect, useRef, useState } from "react";

export interface WsMessage {
  type: string;
  [k: string]: unknown;
}

export interface SocketClose {
  code: number;
  reason: string;
}

const SEALED_CODE = 4423;
const ROOM_FULL_CODE = 4413;
const ROOM_NOT_FOUND_CODE = 4404;
const KICKED_CODE = 4403;

export function describeClose(c: SocketClose | null): string | null {
  if (!c) return null;
  if (c.code === KICKED_CODE) return "방장에게 강퇴되었어요";
  if (c.code === SEALED_CODE) return "이미 시작된 게임이라 입장할 수 없어요";
  if (c.code === ROOM_FULL_CODE) return "방이 가득 찼어요";
  if (c.code === ROOM_NOT_FOUND_CODE) return "방을 찾을 수 없어요";
  if (c.code === 1008) return "인증 실패 (다시 로그인해 주세요)";
  if (c.code === 1000) return null; // normal close
  return c.reason || "연결이 끊어졌어요";
}

export function useGameSocket(roomId: string | undefined, token: string | null) {
  const [messages, setMessages] = useState<WsMessage[]>([]);
  const [connected, setConnected] = useState(false);
  const [closeInfo, setCloseInfo] = useState<SocketClose | null>(null);
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    if (!roomId || !token) return;
    // Prefer an explicit env-set base in production (Vercel can't proxy WS).
    // Fall back to the page origin so the Vite dev proxy keeps working locally.
    const envBase = import.meta.env.VITE_WS_BASE as string | undefined;
    const base =
      envBase && envBase.length > 0
        ? envBase.replace(/\/+$/, "")
        : `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}`;
    const url = `${base}/ws/rooms/${roomId}?token=${encodeURIComponent(token)}`;
    const ws = new WebSocket(url);
    wsRef.current = ws;
    ws.onopen = () => {
      setConnected(true);
      setCloseInfo(null);
    };
    ws.onclose = (evt) => {
      setConnected(false);
      setCloseInfo({ code: evt.code, reason: evt.reason });
    };
    ws.onmessage = (evt) => {
      try {
        const m = JSON.parse(evt.data) as WsMessage;
        setMessages((prev) => [...prev, m]);
      } catch {
        /* ignore */
      }
    };
    return () => {
      ws.close();
      wsRef.current = null;
    };
  }, [roomId, token]);

  function send(payload: WsMessage) {
    wsRef.current?.send(JSON.stringify(payload));
  }

  return { messages, connected, closeInfo, send };
}
