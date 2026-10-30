import { useEffect, useRef, useState } from "react";
import { reloginGuest } from "../api/client";

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
const UNAUTHORIZED_CODE = 4401;
/** Closes that retrying cannot fix (same list as the app's WsGameRoom). */
const FATAL = new Set([KICKED_CODE, ROOM_NOT_FOUND_CODE, ROOM_FULL_CODE, SEALED_CODE]);

export function describeClose(c: SocketClose | null): string | null {
  if (!c) return null;
  if (c.code === KICKED_CODE) return "방장에게 강퇴되었어요";
  if (c.code === SEALED_CODE) return "이미 시작된 게임이라 입장할 수 없어요";
  if (c.code === ROOM_FULL_CODE) return "방이 가득 찼어요";
  if (c.code === ROOM_NOT_FOUND_CODE) return "방이 사라졌어요";
  if (c.code === UNAUTHORIZED_CODE || c.code === 1008) return "로그인이 만료됐어요. 다시 시작해 주세요";
  if (c.code === 1000) return null; // normal close
  return c.reason || "연결이 끊어졌어요";
}

/**
 * Room WebSocket with auto-reconnect (like the app): phones drop sockets when the screen
 * locks or the network switches, so a closed socket is re-opened with backoff, and the
 * server's `room_state` snapshot brings the page back up to date.
 *
 * `onMessage` is called synchronously for EVERY frame, in order. (An earlier version
 * collected frames in React state and handled only the newest per render, which silently
 * dropped bursts such as chat -> correct -> score_update.)
 */
export function useGameSocket(
  roomId: string | undefined,
  token: string | null,
  onMessage: (m: WsMessage) => void
) {
  const [connected, setConnected] = useState(false);
  const [closeInfo, setCloseInfo] = useState<SocketClose | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const handler = useRef(onMessage);
  handler.current = onMessage;
  const authRetries = useRef(0); // one automatic re-login per 4401

  useEffect(() => {
    if (!roomId || !token) return;
    let stopped = false;
    let attempt = 0;
    let timer: ReturnType<typeof setTimeout> | undefined;

    const url = () => {
      const envBase = import.meta.env.VITE_WS_BASE as string | undefined;
      const base =
        envBase && envBase.length > 0
          ? envBase.replace(/\/+$/, "")
          : `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}`;
      return `${base}/ws/rooms/${roomId}?token=${encodeURIComponent(token)}`;
    };

    function open() {
      if (stopped) return;
      clearTimeout(timer);
      const ws = new WebSocket(url());
      wsRef.current = ws;
      ws.onopen = () => {
        attempt = 0;
        authRetries.current = 0;
        setConnected(true);
        setCloseInfo(null);
      };
      ws.onmessage = (evt) => {
        try {
          handler.current(JSON.parse(evt.data) as WsMessage);
        } catch {
          /* ignore malformed frames */
        }
      };
      ws.onclose = async (evt) => {
        if (wsRef.current === ws) wsRef.current = null;
        setConnected(false);
        if (stopped) return;
        if (FATAL.has(evt.code)) {
          setCloseInfo({ code: evt.code, reason: evt.reason });
          return;
        }
        if (evt.code === UNAUTHORIZED_CODE || evt.code === 1008) {
          if (authRetries.current < 1) {
            authRetries.current += 1;
            // success changes the token in the store -> this effect re-runs and reconnects
            if (await reloginGuest()) return;
          }
          setCloseInfo({ code: evt.code, reason: evt.reason });
          return;
        }
        const delay = Math.min(1000 * 2 ** attempt, 8000);
        attempt += 1;
        timer = setTimeout(open, delay);
      };
    }

    // Coming back to the tab (unlock the phone): reconnect at once instead of waiting.
    const onVisible = () => {
      if (document.visibilityState !== "visible" || stopped) return;
      const s = wsRef.current?.readyState;
      if (s === WebSocket.OPEN || s === WebSocket.CONNECTING) return;
      attempt = 0;
      open();
    };
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("online", onVisible);

    open();
    return () => {
      stopped = true;
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("online", onVisible);
      wsRef.current?.close();
      wsRef.current = null;
    };
  }, [roomId, token]);

  function send(payload: WsMessage): boolean {
    const ws = wsRef.current;
    if (!ws || ws.readyState !== WebSocket.OPEN) return false;
    ws.send(JSON.stringify(payload));
    return true;
  }

  return { connected, closeInfo, send };
}
