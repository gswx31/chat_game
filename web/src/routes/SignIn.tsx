import { useEffect, useState } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { authApi, roomsApi } from "../api/client";
import { useAuth } from "../store/auth";

const LAST_NICK_KEY = "last_nickname";

export default function SignIn() {
  const { user, signIn } = useAuth();
  const loc = useLocation();
  const nav = useNavigate();

  const params = new URLSearchParams(loc.search);
  const prefillCode = (params.get("code") || "").toUpperCase();

  const [nickname, setNickname] = useState(() => localStorage.getItem(LAST_NICK_KEY) ?? "");
  const [code, setCode] = useState(prefillCode);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (prefillCode) setCode(prefillCode);
  }, [prefillCode]);

  if (user && code) return <Navigate to={`/j/${code}`} replace />;
  if (user) return <Navigate to="/lobby" replace />;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    const nick = nickname.trim();
    const codeUp = code.trim().toUpperCase();
    if (nick.length < 2) { setErr("닉네임은 2자 이상이어야 해요"); return; }
    setBusy(true);
    try {
      let target: string | null = null;
      if (codeUp) {
        if (!/^[A-Z2-9]{6}$/.test(codeUp)) {
          setErr("방코드는 영문 대문자/숫자 6자리예요");
          setBusy(false);
          return;
        }
        try {
          const room = await roomsApi.getByCode(codeUp);
          if (room.status === "ended") {
            setErr("이미 종료된 게임이에요");
            setBusy(false);
            return;
          }
          target = room.id;
        } catch {
          setErr("해당 코드의 방을 찾을 수 없어요");
          setBusy(false);
          return;
        }
      }
      const r = await authApi.guestLogin(nick);
      signIn(r.access_token, { user_id: r.user_id, nickname: r.nickname });
      localStorage.setItem(LAST_NICK_KEY, r.nickname);
      if (target) nav(`/rooms/${target}`);
      else nav("/lobby");
    } catch (e: any) {
      setErr(e.message ?? "로그인 실패");
    } finally {
      setBusy(false);
    }
  }

  const hasCode = code.trim().length > 0;

  return (
    <div
      style={{
        minHeight: "calc(100vh - 56px)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "24px",
      }}
    >
      <div style={{ width: "100%", maxWidth: 420 }} className="anim-fade-up">
        {/* Hero */}
        <div style={{ textAlign: "center", marginBottom: 36 }}>
          <div
            style={{
              width: 72,
              height: 72,
              borderRadius: "50%",
              background: "var(--grad-primary)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 32,
              margin: "0 auto 16px",
              boxShadow: "0 0 32px rgba(108,99,255,0.4)",
            }}
          >
            🧠
          </div>
          <h1 style={{ fontSize: 26, marginBottom: 8 }}>상식퀴즈배틀</h1>
          <p className="muted" style={{ fontSize: 14, lineHeight: 1.6 }}>
            실시간 멀티플레이어 퀴즈 게임<br />
            친구에게 받은 방코드로 바로 입장하세요
          </p>
        </div>

        {/* Form card */}
        <div className="card" style={{ borderRadius: "var(--radius-lg)" }}>
          <form onSubmit={submit} className="stack">
            <div className="col" style={{ gap: 6 }}>
              <label style={{ fontSize: 13, fontWeight: 600, color: "var(--text-muted)" }}>
                닉네임
              </label>
              <input
                autoFocus
                placeholder="2~20자로 입력하세요"
                value={nickname}
                onChange={(e) => setNickname(e.target.value)}
                maxLength={20}
                style={{ borderRadius: "var(--radius-sm)" }}
              />
            </div>

            <div className="col" style={{ gap: 6 }}>
              <label style={{ fontSize: 13, fontWeight: 600, color: "var(--text-muted)" }}>
                방코드 <span style={{ fontWeight: 400, opacity: 0.6 }}>(선택)</span>
              </label>
              <input
                placeholder="ABCD42"
                value={code}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
                maxLength={6}
                style={{
                  letterSpacing: 6,
                  fontFamily: "ui-monospace, monospace",
                  fontWeight: 700,
                  fontSize: 18,
                  textAlign: "center",
                  borderRadius: "var(--radius-sm)",
                  borderColor: hasCode ? "var(--border-focus)" : undefined,
                }}
              />
            </div>

            {err && (
              <div
                style={{
                  background: "rgba(239,68,68,0.1)",
                  border: "1px solid rgba(239,68,68,0.3)",
                  borderRadius: "var(--radius-sm)",
                  padding: "9px 14px",
                  color: "#fca5a5",
                  fontSize: 14,
                }}
              >
                {err}
              </div>
            )}

            <button
              type="submit"
              disabled={busy}
              style={{
                marginTop: 4,
                padding: "12px",
                fontSize: 15,
                borderRadius: "var(--radius-sm)",
                background: hasCode ? "var(--grad-accent)" : "var(--grad-primary)",
              }}
            >
              {busy ? "잠시만요..." : hasCode ? "코드로 바로 입장" : "로비로 이동"}
            </button>
          </form>
        </div>

        <p className="muted" style={{ textAlign: "center", marginTop: 20, fontSize: 12 }}>
          별도 회원가입 없이 닉네임만으로 플레이 가능해요
        </p>
      </div>
    </div>
  );
}
