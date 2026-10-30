import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { roomsApi } from "../api/client";
import { AppBar } from "../components/AppBar";
import { roomPath } from "../lib/paths";
import { useAuth } from "../store/auth";
import SignIn from "./SignIn";

/**
 * `/j/:code` — the link a friend shares. Not signed in: nickname step with the invitation
 * shown. Signed in: look the room up and walk straight in.
 */
export default function Join() {
  const { code = "" } = useParams();
  const user = useAuth((s) => s.user);
  const nav = useNavigate();
  const [err, setErr] = useState<string | null>(null);
  const upper = code.toUpperCase();

  useEffect(() => {
    if (!user || !upper) return;
    let cancelled = false;
    (async () => {
      try {
        const room = await roomsApi.getByCode(upper);
        if (cancelled) return;
        if (room.status === "ended") {
          setErr("이미 종료된 게임이에요");
          return;
        }
        nav(roomPath(room.id), { replace: true });
      } catch {
        if (!cancelled) setErr("해당 코드의 방을 찾을 수 없어요");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [user, upper, nav]);

  if (!user) return <SignIn inviteCode={upper} />;

  return (
    <div className="app-page">
      <AppBar title="방 입장" back="/home" />
      <div className="page-body">
        {err ? (
          <div className="empty">
            <div className="empty__icon">😕</div>
            <div className="empty__title">입장할 수 없어요</div>
            <div className="empty__text">{err}</div>
            <button className="btn" onClick={() => nav("/home", { replace: true })}>
              메인으로 돌아가기
            </button>
          </div>
        ) : (
          <div className="empty">
            <span className="spinner" />
            <div className="empty__title">방 입장 중...</div>
            <div className="empty__text">
              코드 <b className="mono">{upper}</b>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
