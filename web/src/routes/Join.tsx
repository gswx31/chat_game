import { useEffect, useState } from "react";
import { Navigate, useNavigate, useParams } from "react-router-dom";
import { roomsApi } from "../api/client";
import { useAuth } from "../store/auth";

export default function Join() {
  const { code } = useParams();
  const { user } = useAuth();
  const nav = useNavigate();
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!user || !code) return;
    let cancelled = false;
    (async () => {
      try {
        const room = await roomsApi.getByCode(code);
        if (cancelled) return;
        if (room.status === "ended") { setErr("이미 종료된 게임이에요"); return; }
        nav(`/rooms/${room.id}`, { replace: true });
      } catch {
        if (!cancelled) setErr("해당 코드의 방을 찾을 수 없어요");
      }
    })();
    return () => { cancelled = true; };
  }, [user, code, nav]);

  if (!user) return <Navigate to={`/?code=${encodeURIComponent(code ?? "")}`} replace />;

  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "60vh" }}>
      <div className="card anim-fade-up" style={{ maxWidth: 380, borderRadius: "var(--radius-lg)", textAlign: "center", padding: "40px 28px" }}>
        {err ? (
          <>
            <div style={{ fontSize: 36, marginBottom: 14 }}>😕</div>
            <h3 style={{ marginBottom: 10 }}>입장할 수 없어요</h3>
            <div className="muted" style={{ marginBottom: 24 }}>{err}</div>
            <button onClick={() => nav("/lobby")}>로비로 돌아가기</button>
          </>
        ) : (
          <>
            <div style={{ fontSize: 36, marginBottom: 14, animation: "pulse 1.2s infinite" }}>🚪</div>
            <div style={{ fontWeight: 600, marginBottom: 6 }}>방 입장 중...</div>
            <div className="muted">코드 <span style={{ color: "var(--primary-light)", fontFamily: "monospace", fontWeight: 700 }}>{code}</span></div>
          </>
        )}
      </div>
    </div>
  );
}
