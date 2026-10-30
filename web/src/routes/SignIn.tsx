import { useEffect, useState, type FormEvent } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { authApi, friendlyError, roomsApi, type RoomDetail } from "../api/client";
import { BrandBlock } from "../components/Brand";
import { TermsConsent } from "../components/TermsGate";
import { roomPath } from "../lib/paths";
import { useAuth } from "../store/auth";
import { useTerms } from "../store/terms";

const LAST_NICK_KEY = "last_nickname";

/**
 * Entry screen: pick a nickname and play (no sign-up). With `inviteCode` (the page behind a
 * shared `/j/CODE` link) it shows the invitation and, once the nickname is set, the parent
 * `Join` page takes the player straight into that room.
 */
export default function SignIn({ inviteCode }: { inviteCode?: string }) {
  const { user, signIn } = useAuth();
  const loc = useLocation();
  const nav = useNavigate();

  const params = new URLSearchParams(loc.search);
  const prefill = (inviteCode ?? params.get("code") ?? "").toUpperCase();
  const from = (loc.state as { from?: string } | null)?.from;

  const [nickname, setNickname] = useState(() => {
    try {
      return localStorage.getItem(LAST_NICK_KEY) ?? "";
    } catch {
      return "";
    }
  });
  const [code, setCode] = useState(prefill);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [agree, setAgree] = useState(() => useTerms.getState().accepted);

  // invitation preview: whose room, how many people are in it
  const [room, setRoom] = useState<RoomDetail | null>(null);
  const [roomState, setRoomState] = useState<"idle" | "loading" | "ok" | "missing" | "ended">("idle");
  useEffect(() => {
    if (!inviteCode) return;
    let alive = true;
    setRoomState("loading");
    roomsApi
      .getByCode(inviteCode)
      .then((r) => {
        if (!alive) return;
        setRoom(r);
        setRoomState(r.status === "ended" ? "ended" : "ok");
      })
      .catch(() => alive && setRoomState("missing"));
    return () => {
      alive = false;
    };
  }, [inviteCode]);

  if (user && !inviteCode) return <Navigate to={prefill ? `/j/${prefill}` : from || "/home"} replace />;

  async function submit(e: FormEvent) {
    e.preventDefault();
    setErr(null);
    const nick = nickname.trim();
    const codeUp = code.trim().toUpperCase();
    if (nick.length < 2) {
      setErr("닉네임은 2자 이상이어야 해요");
      return;
    }
    if (!agree) {
      setErr("이용약관·운영정책에 동의해 주세요");
      return;
    }
    setBusy(true);
    try {
      let target: string | null = null;
      if (!inviteCode && codeUp) {
        if (!/^[A-Z2-9]{6}$/.test(codeUp)) {
          setErr("방코드는 영문 대문자/숫자 6자리예요");
          return;
        }
        try {
          const r = await roomsApi.getByCode(codeUp);
          if (r.status === "ended") {
            setErr("이미 종료된 게임이에요");
            return;
          }
          target = r.id;
        } catch {
          setErr("해당 코드의 방을 찾을 수 없어요");
          return;
        }
      }
      const r = await authApi.guestLogin(nick);
      try {
        localStorage.setItem(LAST_NICK_KEY, r.nickname);
      } catch {
        /* private mode */
      }
      useTerms.getState().accept();
      signIn(r.access_token, { user_id: r.user_id, nickname: r.nickname });
      // invitation: the Join page (which renders this component) sees the new user and walks
      // into the room; otherwise go where the player was headed.
      if (!inviteCode) nav(target ? roomPath(target) : from || "/home", { replace: true });
    } catch (e2) {
      setErr(friendlyError(e2));
    } finally {
      setBusy(false);
    }
  }

  const invited = !!inviteCode;
  const roomOk = invited && roomState === "ok";
  const hasCode = code.trim().length > 0;

  return (
    <div className="signin">
      <div className="signin__col">
        <div className="signin__hero anim-up">
          <BrandBlock mascot={invited ? 104 : 124} word={42} />
          <h1 className="headline">{invited ? "초대장이 도착했어요!" : "채팅창에 먼저 치면 정답!"}</h1>
          <p className="headline__sub">
            {invited ? "닉네임만 정하면 친구가 있는 방으로 바로 들어가요" : "친구와 실시간으로 겨루는 상식 퀴즈 · 회원가입 없이 닉네임만으로 시작해요"}
          </p>
        </div>

        <form className="signin__sheet card anim-up" onSubmit={submit} noValidate>
          {invited ? (
            <div className={`invite-preview ${roomState === "missing" || roomState === "ended" ? "is-bad" : ""}`}>
              {roomState === "loading" || roomState === "idle" ? (
                <span className="muted">초대받은 방을 확인하는 중...</span>
              ) : roomOk && room ? (
                <>
                  <div className="invite-preview__name">“{room.name}”</div>
                  <div className="invite-preview__meta">
                    <span className="mono">{room.code}</span> · {room.player_count}명 접속 · 선 {room.win_score}점
                  </div>
                </>
              ) : roomState === "ended" ? (
                <span>이미 종료된 게임이에요. 닉네임을 정하고 새 방에서 놀아요</span>
              ) : (
                <span>
                  <b className="mono">{inviteCode}</b> 방을 찾을 수 없어요. 닉네임을 정하고 직접 방을 만들어요
                </span>
              )}
            </div>
          ) : null}

          <div className="field">
            <label className="field__label" htmlFor="nick">
              닉네임
            </label>
            <input
              id="nick"
              className="input"
              placeholder="2~20자로 입력하세요"
              value={nickname}
              maxLength={20}
              autoComplete="nickname"
              autoCapitalize="off"
              autoFocus={!invited}
              onChange={(e) => setNickname(e.target.value)}
            />
          </div>

          {!invited ? (
            <div className="field">
              <label className="field__label" htmlFor="room-code">
                방코드 <span className="muted">(선택)</span>
              </label>
              <input
                id="room-code"
                className="input input--code mono"
                placeholder="ABCD42"
                value={code}
                maxLength={6}
                autoCapitalize="characters"
                autoCorrect="off"
                spellCheck={false}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
              />
            </div>
          ) : null}

          <TermsConsent checked={agree} onChange={setAgree} />

          {err ? <div className="field-error signin__err">{err}</div> : null}

          <button className={`btn btn--block ${roomOk || hasCode ? "btn--accent" : ""}`} type="submit" disabled={busy}>
            {busy ? "잠시만요..." : roomOk ? "초대받은 방에 입장 🎮" : hasCode ? "코드로 바로 입장" : "시작하기"}
          </button>
        </form>
      </div>
    </div>
  );
}
