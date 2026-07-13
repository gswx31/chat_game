import { useEffect, useMemo, useRef, useState } from "react";
import { Navigate, useNavigate, useParams } from "react-router-dom";
import { roomsApi, type RoomDetail } from "../api/client";
import { useAuth } from "../store/auth";
import { describeClose, useGameSocket, type WsMessage } from "../ws/useGameSocket";

// ── Types ──────────────────────────────────────────────────────────────────
interface PlayerRow {
  user_id: string;
  nickname: string;
  score: number;
  online?: boolean;
}
interface RoundState {
  round: number;
  prompt: string;
  category: string;
  difficulty: number;
  deadline_ts: number;
  hint?: string;
  ended?: { reason: "correct" | "timeout" | "skipped"; answer: string; nickname?: string };
}
interface ChatRow {
  id: number;
  user_id?: string;
  nickname: string;
  text: string;
  kind: "chat" | "system";
}

// ── Room page ──────────────────────────────────────────────────────────────
export default function Room() {
  const { roomId } = useParams();
  const { user, token } = useAuth();
  const nav = useNavigate();

  const [room, setRoom] = useState<RoomDetail | null>(null);
  const [status, setStatus] = useState<"waiting" | "playing" | "ended">("waiting");
  const [ownerId, setOwnerId] = useState<string | null>(null);
  const [winScore, setWinScore] = useState(20);
  const [players, setPlayers] = useState<PlayerRow[]>([]);
  const [round, setRound] = useState<RoundState | null>(null);
  const [chat, setChat] = useState<ChatRow[]>([]);
  const [skipState, setSkipState] = useState<{ votes: number; needed: number } | null>(null);
  const [finalResult, setFinalResult] = useState<{ scores: PlayerRow[]; winner_id: string | null } | null>(null);
  const [input, setInput] = useState("");

  const logRef = useRef<HTMLDivElement>(null);
  const chatSeq = useRef(0);
  const dingRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    const a = new Audio("/sounds/ding.mp3");
    a.volume = 0.4;
    a.preload = "auto";
    dingRef.current = a;
  }, []);

  const { messages, connected, closeInfo, send } = useGameSocket(roomId, token);
  const closeMsg = describeClose(closeInfo);

  useEffect(() => {
    if (!roomId) return;
    roomsApi.get(roomId).then(setRoom).catch(() => setRoom(null));
  }, [roomId]);

  useEffect(() => {
    if (messages.length === 0) return;
    handleMessage(messages[messages.length - 1]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [messages]);

  useEffect(() => {
    logRef.current?.scrollTo({ top: logRef.current.scrollHeight, behavior: "smooth" });
  }, [chat]);

  function pushChat(row: Omit<ChatRow, "id">) {
    chatSeq.current += 1;
    setChat((prev) => [...prev.slice(-300), { ...row, id: chatSeq.current }]);
  }

  function handleMessage(m: WsMessage) {
    switch (m.type) {
      case "room_state": {
        const next = m.status as "waiting" | "playing" | "ended";
        setStatus(next);
        setOwnerId((m.owner_id as string) ?? null);
        setWinScore((m.win_score as number) ?? 20);
        setPlayers((m.players as PlayerRow[]) ?? []);
        if (m.current) {
          const c = m.current as any;
          setRound({ round: c.round, prompt: c.prompt, category: c.category, difficulty: c.difficulty, deadline_ts: c.deadline_ts });
        } else setRound(null);
        if (next === "waiting") { setFinalResult(null); setSkipState(null); }
        break;
      }
      case "player_join":
        pushChat({ nickname: String(m.nickname), text: "입장했습니다", kind: "system" });
        break;
      case "player_leave":
        pushChat({ nickname: String(m.nickname), text: "나갔습니다", kind: "system" });
        break;
      case "chat":
        pushChat({ user_id: String(m.user_id), nickname: String(m.nickname), text: String(m.text), kind: "chat" });
        break;
      case "game_start":
        setStatus("playing");
        setFinalResult(null);
        pushChat({ nickname: "system", text: "🎮 게임 시작!", kind: "system" });
        break;
      case "round_start":
        setRound({ round: m.round as number, prompt: String(m.prompt), category: String(m.category), difficulty: m.difficulty as number, deadline_ts: m.deadline_ts as number });
        setSkipState(null);
        break;
      case "hint":
        setRound((r) => r ? { ...r, hint: String(m.hint) } : r);
        pushChat({ nickname: "system", text: `💡 힌트: ${m.hint}`, kind: "system" });
        break;
      case "skip_progress":
        setSkipState({ votes: m.votes as number, needed: m.needed as number });
        break;
      case "correct":
        setRound((r) => r ? { ...r, ended: { reason: "correct", answer: String(m.answer), nickname: String(m.nickname) } } : r);
        pushChat({ nickname: "system", text: `✅ ${m.nickname}님 정답! (${m.answer})`, kind: "system" });
        try { if (dingRef.current) { dingRef.current.currentTime = 0; dingRef.current.play().catch(() => {}); } } catch { /**/ }
        break;
      case "player_kicked":
        pushChat({ nickname: "system", text: `🚫 ${m.nickname}님이 강퇴되었어요`, kind: "system" });
        break;
      case "round_end":
        setRound((r) => r ? { ...r, ended: { reason: m.reason as "timeout" | "skipped", answer: String(m.answer) } } : r);
        pushChat({ nickname: "system", text: m.reason === "skipped" ? `⏭️ 스킵됨 (정답: ${m.answer})` : `⌛ 시간 초과 (정답: ${m.answer})`, kind: "system" });
        break;
      case "score_update":
        setPlayers((m.scores as PlayerRow[]) ?? []);
        break;
      case "game_over":
        setStatus("ended");
        setFinalResult({ scores: (m.scores as PlayerRow[]) ?? [], winner_id: (m.winner_id as string) ?? null });
        break;
      case "error":
        pushChat({ nickname: "system", text: `⚠️ ${m.message}`, kind: "system" });
        break;
    }
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    const t = input.trim();
    if (!t || !connected) return;
    send({ type: "chat", text: t });
    setInput("");
  }

  const isOwner = ownerId === user?.user_id;

  if (!user) return <Navigate to="/" replace />;

  if (closeMsg && !connected) {
    return (
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "60vh" }}>
        <div className="card anim-fade-up" style={{ maxWidth: 420, borderRadius: "var(--radius-lg)", textAlign: "center", padding: "36px" }}>
          <div style={{ fontSize: 40, marginBottom: 16 }}>🚪</div>
          <h3 style={{ marginBottom: 10 }}>입장할 수 없어요</h3>
          <div className="muted" style={{ marginBottom: 24, lineHeight: 1.6 }}>{closeMsg}</div>
          <button onClick={() => nav("/lobby")}>로비로 돌아가기</button>
        </div>
      </div>
    );
  }

  return (
    <div className="room-layout anim-fade-up">
      {/* Left: question + chat */}
      <div className="stack" style={{ minWidth: 0 }}>
        {/* Room header */}
        <div className="card" style={{ borderRadius: "var(--radius-lg)", padding: "14px 18px" }}>
          <div className="row wrap" style={{ justifyContent: "space-between", gap: 10 }}>
            <div style={{ minWidth: 0 }}>
              <div className="row" style={{ gap: 8, marginBottom: 4, flexWrap: "wrap" }}>
                <h2 style={{ fontSize: 17, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", maxWidth: 260 }}>
                  {room?.name ?? roomId}
                </h2>
                <ConnectionDot connected={connected} />
                <StatusBadge status={status} />
              </div>
              <div className="muted" style={{ fontSize: 12 }}>
                선 {winScore}점 · {room?.round_seconds ?? "?"}초/라운드
              </div>
            </div>
            {room?.code && <InviteBadge code={room.code} />}
          </div>

          {/* Action buttons */}
          <div className="row" style={{ marginTop: 10, gap: 8, flexWrap: "wrap" }}>
            {status === "waiting" && isOwner && (
              <button onClick={() => send({ type: "start_game" })} disabled={!connected} className="btn-accent btn-sm">
                🎮 게임 시작
              </button>
            )}
            {status === "playing" && round && !round.ended && (
              <button onClick={() => send({ type: "skip" })} disabled={!connected} className="btn-ghost btn-sm">
                ⏭️ 스킵{skipState ? ` (${skipState.votes}/${skipState.needed})` : ""}
              </button>
            )}
            <button onClick={() => nav("/lobby")} className="btn-ghost btn-sm" style={{ marginLeft: "auto" }}>
              ← 로비
            </button>
          </div>
        </div>

        {/* Question panel */}
        <QuestionPanel round={round} status={status} />

        {/* Chat */}
        <div className="chat" style={{ flex: 1, minHeight: 260 }}>
          <div ref={logRef} className="chat-log">
            {chat.length === 0 && (
              <div style={{ textAlign: "center", color: "var(--text-dim)", fontSize: 13, marginTop: 16 }}>
                메시지가 없어요 — 정답 또는 대화를 입력하세요
              </div>
            )}
            {chat.map((c) =>
              c.kind === "system" ? (
                <div key={c.id} className="chat-msg chat-msg-system">{c.text}</div>
              ) : (
                <div key={c.id} className={`chat-msg ${c.user_id === user.user_id ? "chat-msg-me" : "chat-msg-user"}`}>
                  {c.user_id !== user.user_id && <div className="chat-who">{c.nickname}</div>}
                  <div style={{ fontSize: 14 }}>{c.text}</div>
                </div>
              )
            )}
          </div>
          <form onSubmit={submit} className="chat-input">
            <input
              placeholder={connected ? "메시지 또는 정답 입력..." : "연결 중..."}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              disabled={!connected}
              maxLength={200}
            />
            <button type="submit" disabled={!connected || !input.trim()} style={{ flexShrink: 0, padding: "8px 14px" }}>
              전송
            </button>
          </form>
        </div>
      </div>

      {/* Right: scoreboard */}
      <Scoreboard
        players={players}
        winScore={winScore}
        ownerId={ownerId}
        meId={user.user_id}
        canKick={status === "waiting" && isOwner}
        onKick={(uid) => {
          if (!confirm("이 플레이어를 강퇴할까요?")) return;
          send({ type: "kick", target_user_id: uid });
        }}
      />

      {/* Result modal */}
      {finalResult && (
        <ResultModal
          scores={finalResult.scores}
          winnerId={finalResult.winner_id}
          meId={user.user_id}
          isOwner={isOwner}
          onClose={() => setFinalResult(null)}
          onLobby={() => nav("/lobby")}
          onRematch={() => send({ type: "rematch" })}
        />
      )}
    </div>
  );
}

// ── QuestionPanel ──────────────────────────────────────────────────────────
function QuestionPanel({ round, status }: { round: RoundState | null; status: string }) {
  if (status === "waiting") {
    return (
      <div className="card question-panel question-panel-waiting" style={{ padding: "32px 24px", borderRadius: "var(--radius-lg)", textAlign: "center" }}>
        <div style={{ fontSize: 32, marginBottom: 12 }}>⏳</div>
        <div style={{ fontWeight: 600, marginBottom: 6 }}>게임 시작 대기 중</div>
        <div className="muted">방장이 게임을 시작하면 바로 시작돼요</div>
      </div>
    );
  }
  if (!round) {
    return (
      <div className="card question-panel" style={{ padding: "28px 24px", borderRadius: "var(--radius-lg)", textAlign: "center" }}>
        <div className="muted" style={{ animation: "pulse 1.2s infinite" }}>다음 문제 준비 중...</div>
      </div>
    );
  }

  return (
    <div className="card question-panel" style={{ borderRadius: "var(--radius-lg)", padding: "20px 24px" }}>
      {/* Meta row */}
      <div className="row" style={{ justifyContent: "space-between", marginBottom: 16 }}>
        <div className="row" style={{ gap: 8, flexWrap: "wrap" }}>
          <span className="badge badge-primary">Round {round.round}</span>
          <span className="badge badge-muted">{round.category}</span>
          <DifficultyStars level={round.difficulty} />
        </div>
        <ArcTimer deadline={round.deadline_ts} ended={!!round.ended} />
      </div>

      {/* Question */}
      <div className="question-prompt" style={{ marginBottom: 14 }}>{round.prompt}</div>

      {/* Hint */}
      {round.hint && !round.ended && (
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 6,
            background: "rgba(245,158,11,0.1)",
            border: "1px solid rgba(245,158,11,0.25)",
            borderRadius: "var(--radius-sm)",
            padding: "7px 12px",
            color: "var(--warn)",
            fontSize: 14,
            fontWeight: 600,
            marginBottom: 10,
          }}
        >
          💡 힌트: {round.hint}
        </div>
      )}

      {/* Result banner */}
      {round.ended && (
        <div className={`round-banner ${
          round.ended.reason === "correct" ? "round-banner-correct"
          : round.ended.reason === "skipped" ? "round-banner-skipped"
          : "round-banner-timeout"
        }`}>
          {round.ended.reason === "correct"
            ? `🎉 ${round.ended.nickname} 정답! → ${round.ended.answer}`
            : round.ended.reason === "skipped"
            ? `⏭️ 스킵됨 — 정답: ${round.ended.answer}`
            : `⌛ 시간 초과 — 정답: ${round.ended.answer}`}
        </div>
      )}
    </div>
  );
}

// ── ArcTimer ───────────────────────────────────────────────────────────────
function ArcTimer({ deadline, ended }: { deadline: number; ended: boolean }) {
  const [now, setNow] = useState(() => Date.now() / 1000);
  const totalRef = useRef<number | null>(null);

  useEffect(() => {
    if (ended) return;
    totalRef.current = null;
    const id = setInterval(() => setNow(Date.now() / 1000), 100);
    return () => clearInterval(id);
  }, [ended, deadline]);

  const remain = Math.max(0, deadline - now);
  if (totalRef.current === null) totalRef.current = remain;
  const total = totalRef.current || 30;
  const progress = ended ? 0 : remain / total;

  const size = 52;
  const stroke = 4;
  const r = (size - stroke) / 2;
  const circ = 2 * Math.PI * r;
  const dash = circ * progress;

  const color = progress > 0.5 ? "#00c896" : progress > 0.25 ? "#f59e0b" : "#ef4444";

  return (
    <div className="arc-timer" style={{ width: size, height: size, position: "relative", flexShrink: 0 }}>
      <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="rgba(255,255,255,0.07)" strokeWidth={stroke} />
        <circle
          cx={size / 2} cy={size / 2} r={r}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeDasharray={`${dash} ${circ}`}
          strokeLinecap="round"
          style={{ transition: "stroke-dasharray 0.1s linear, stroke 0.3s" }}
        />
      </svg>
      <div style={{
        position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center",
        fontFamily: "ui-monospace, monospace", fontSize: 13, fontWeight: 700, color,
      }}>
        {ended ? "—" : Math.ceil(remain)}
      </div>
    </div>
  );
}

// ── DifficultyStars ────────────────────────────────────────────────────────
function DifficultyStars({ level }: { level: number }) {
  const stars = Math.min(5, Math.max(1, level));
  return (
    <span style={{ color: "var(--warn)", fontSize: 12, letterSpacing: 1 }}>
      {"★".repeat(stars)}{"☆".repeat(5 - stars)}
    </span>
  );
}

// ── ConnectionDot ──────────────────────────────────────────────────────────
function ConnectionDot({ connected }: { connected: boolean }) {
  return (
    <span
      style={{
        width: 8, height: 8, borderRadius: "50%", flexShrink: 0,
        background: connected ? "var(--accent)" : "var(--danger)",
        boxShadow: connected ? "0 0 6px var(--accent)" : "none",
        display: "inline-block",
      }}
      title={connected ? "연결됨" : "연결 끊김"}
    />
  );
}

// ── StatusBadge ────────────────────────────────────────────────────────────
function StatusBadge({ status }: { status: string }) {
  if (status === "playing") return <span className="badge badge-warn">진행중</span>;
  if (status === "ended") return <span className="badge badge-muted">종료</span>;
  return <span className="badge badge-accent">대기중</span>;
}

// ── InviteBadge ────────────────────────────────────────────────────────────
function InviteBadge({ code }: { code: string }) {
  const [copied, setCopied] = useState<"code" | "link" | null>(null);
  const shareUrl = `${location.origin}/j/${code}`;

  async function copy(text: string, what: "code" | "link") {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(what);
      setTimeout(() => setCopied(null), 1500);
    } catch { /**/ }
  }

  return (
    <div className="row" style={{ gap: 6, flexWrap: "wrap" }}>
      <div className="invite-badge" style={{ fontSize: 18, letterSpacing: 4 }}>{code}</div>
      <button className="btn-ghost btn-sm" onClick={() => copy(code, "code")}>
        {copied === "code" ? "✓ 복사됨" : "코드"}
      </button>
      <button className="btn-ghost btn-sm" onClick={() => copy(shareUrl, "link")}>
        {copied === "link" ? "✓ 복사됨" : "링크"}
      </button>
    </div>
  );
}

// ── Scoreboard ─────────────────────────────────────────────────────────────
function Scoreboard({
  players, winScore, ownerId, meId, canKick, onKick,
}: {
  players: PlayerRow[]; winScore: number; ownerId: string | null;
  meId: string; canKick: boolean; onKick: (uid: string) => void;
}) {
  const sorted = useMemo(() => [...players].sort((a, b) => b.score - a.score), [players]);

  return (
    <aside className="card room-side" style={{ borderRadius: "var(--radius-lg)", padding: "18px" }}>
      <div className="row" style={{ justifyContent: "space-between", marginBottom: 14 }}>
        <div style={{ fontWeight: 700, fontSize: 15 }}>점수판</div>
        <span className="badge badge-primary">선 {winScore}점</span>
      </div>

      {sorted.length === 0 ? (
        <div className="muted" style={{ textAlign: "center", padding: "20px 0" }}>플레이어 없음</div>
      ) : (
        <div className="col" style={{ gap: 10 }}>
          {sorted.map((p, i) => {
            const pct = Math.min(100, (p.score / Math.max(1, winScore)) * 100);
            const isMe = p.user_id === meId;
            return (
              <div key={p.user_id} className="score-row">
                <div className="row" style={{ justifyContent: "space-between", marginBottom: 5 }}>
                  <div className="row" style={{ gap: 6, minWidth: 0 }}>
                    <span style={{ fontSize: 13, color: "var(--text-dim)", flexShrink: 0, width: 18, textAlign: "right" }}>
                      {i + 1}
                    </span>
                    <span className={`score-name ${isMe ? "score-name-me" : ""}`} style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {p.nickname}
                    </span>
                    {p.user_id === ownerId && <span style={{ fontSize: 12 }}>👑</span>}
                    {p.online === false && <span className="muted" style={{ fontSize: 11 }}>(offline)</span>}
                  </div>
                  <div className="row" style={{ gap: 6, flexShrink: 0 }}>
                    <span style={{ fontWeight: 700, fontSize: 14 }}>{p.score}</span>
                    {canKick && p.user_id !== meId && p.online !== false && (
                      <button
                        onClick={() => onKick(p.user_id)}
                        title="강퇴"
                        style={{ background: "transparent", color: "var(--danger)", border: "1px solid rgba(239,68,68,0.3)", padding: "1px 7px", minHeight: 22, fontSize: 11, borderRadius: 4 }}
                      >
                        강퇴
                      </button>
                    )}
                  </div>
                </div>
                <div className="progress-track">
                  <div
                    className="progress-bar"
                    style={{
                      width: `${pct}%`,
                      background: isMe ? "var(--grad-accent)" : "var(--grad-primary)",
                    }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      )}
    </aside>
  );
}

// ── ResultModal ────────────────────────────────────────────────────────────
function ResultModal({
  scores, winnerId, meId, isOwner, onClose, onLobby, onRematch,
}: {
  scores: PlayerRow[]; winnerId: string | null; meId: string;
  isOwner: boolean; onClose: () => void; onLobby: () => void; onRematch: () => void;
}) {
  const top3 = scores.slice(0, 3);
  const podiumOrder = top3.length < 2 ? [0] : top3.length === 2 ? [1, 0] : [1, 0, 2];
  const podiumHeights = [80, 110, 60];
  const podiumColors = ["rgba(192,192,192,0.3)", "rgba(255,215,0,0.3)", "rgba(205,127,50,0.3)"];
  const podiumBorders = ["rgba(192,192,192,0.5)", "rgba(255,215,0,0.6)", "rgba(205,127,50,0.5)"];
  const medals = ["🥈", "🥇", "🥉"];

  return (
    <div className="modal-overlay anim-fade-in" onClick={onClose}>
      <div className="modal-box anim-fade-up" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div style={{ textAlign: "center", marginBottom: 20 }}>
          <div style={{ fontSize: 40, marginBottom: 8 }}>🏆</div>
          <h2 style={{ fontSize: 20, marginBottom: 4 }}>게임 종료!</h2>
          {scores[0] && (
            <div className="muted">
              우승: <span style={{ color: "var(--warn)", fontWeight: 700 }}>{scores[0].nickname}</span> ({scores[0].score}점)
            </div>
          )}
        </div>

        {/* Podium */}
        {top3.length > 0 && (
          <div className="podium" style={{ alignItems: "flex-end", marginBottom: 20 }}>
            {podiumOrder.map((rank) => {
              const p = top3[rank];
              if (!p) return null;
              const podiumIdx = podiumOrder.indexOf(rank);
              return (
                <div key={p.user_id} className="podium-slot">
                  <div style={{ fontSize: 22, marginBottom: 4 }}>{medals[podiumIdx]}</div>
                  <div
                    className="podium-avatar"
                    style={{ border: `2px solid ${podiumBorders[podiumIdx]}`, background: "var(--surface)" }}
                  >
                    {p.nickname.slice(0, 1)}
                  </div>
                  <div className="podium-name">{p.nickname}</div>
                  <div className="podium-score">{p.score}점</div>
                  <div
                    className="podium-bar"
                    style={{ height: podiumHeights[podiumIdx], background: podiumColors[podiumIdx], border: `1px solid ${podiumBorders[podiumIdx]}` }}
                  >
                    <span style={{ fontSize: 16, fontWeight: 800 }}>{rank + 1}</span>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        <div className="divider" style={{ marginBottom: 14 }} />

        {/* Full rank list */}
        <div className="col" style={{ gap: 6, marginBottom: 20 }}>
          {scores.map((p, i) => (
            <div
              key={p.user_id}
              className="row"
              style={{
                justifyContent: "space-between",
                padding: "8px 12px",
                borderRadius: "var(--radius-sm)",
                background: p.user_id === winnerId ? "rgba(255,215,0,0.08)" : p.user_id === meId ? "rgba(108,99,255,0.1)" : "var(--surface)",
                border: p.user_id === meId ? "1px solid rgba(108,99,255,0.2)" : "1px solid transparent",
              }}
            >
              <div className="row" style={{ gap: 8 }}>
                <span style={{ width: 22, textAlign: "center" }}>
                  {i === 0 ? "🥇" : i === 1 ? "🥈" : i === 2 ? "🥉" : `${i + 1}.`}
                </span>
                <span style={{ fontWeight: p.user_id === meId ? 700 : 500 }}>{p.nickname}</span>
                {p.user_id === winnerId && <span>🎉</span>}
              </div>
              <span style={{ fontWeight: 700, color: "var(--primary-light)" }}>{p.score}점</span>
            </div>
          ))}
        </div>

        {/* Buttons */}
        <div className="row" style={{ justifyContent: "flex-end", gap: 8, flexWrap: "wrap" }}>
          <button className="btn-ghost btn-sm" onClick={onLobby}>로비로</button>
          {isOwner ? (
            <button className="btn-accent btn-sm" onClick={onRematch}>🔄 리매치</button>
          ) : (
            <span className="muted" style={{ fontSize: 12, alignSelf: "center" }}>방장이 리매치하면 다시 시작돼요</span>
          )}
        </div>
      </div>
    </div>
  );
}
