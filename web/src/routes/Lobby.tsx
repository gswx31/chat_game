import { useEffect, useRef, useState } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { questionsApi, roomsApi, type RoomListItem } from "../api/client";
import { useAuth } from "../store/auth";

export default function Lobby() {
  const { user } = useAuth();
  const [rooms, setRooms] = useState<RoomListItem[]>([]);
  const [cats, setCats] = useState<string[]>([]);
  const [showCreate, setShowCreate] = useState(false);
  const [code, setCode] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const nav = useNavigate();

  async function refresh() {
    try { setRooms(await roomsApi.list()); } catch (e: any) { setErr(e.message); }
  }

  useEffect(() => {
    refresh();
    questionsApi.categories().then(setCats).catch(() => {});
    const id = setInterval(refresh, 5000);
    return () => clearInterval(id);
  }, []);

  if (!user) return <Navigate to="/" replace />;

  function joinByCode(e: React.FormEvent) {
    e.preventDefault();
    const c = code.trim().toUpperCase();
    if (c.length !== 6) { setErr("방코드는 6자리예요"); return; }
    nav(`/j/${c}`);
  }

  return (
    <div className="stack anim-fade-up" style={{ maxWidth: 1000, margin: "0 auto" }}>
      {/* Top bar: code input + create */}
      <div className="card" style={{ borderRadius: "var(--radius-lg)", padding: "16px 20px" }}>
        <div className="row wrap" style={{ justifyContent: "space-between", gap: 12 }}>
          <form onSubmit={joinByCode} className="row" style={{ gap: 8 }}>
            <div style={{ position: "relative" }}>
              <input
                placeholder="ABCD42"
                value={code}
                onChange={(e) => { setCode(e.target.value.toUpperCase()); setErr(null); }}
                maxLength={6}
                style={{
                  letterSpacing: 5,
                  fontFamily: "ui-monospace, monospace",
                  fontWeight: 700,
                  fontSize: 16,
                  width: 150,
                  minHeight: 38,
                  textAlign: "center",
                  borderColor: code.length === 6 ? "var(--border-focus)" : undefined,
                }}
              />
            </div>
            <button type="submit" className="btn-accent" style={{ whiteSpace: "nowrap" }}>
              코드로 입장
            </button>
          </form>
          <button onClick={() => setShowCreate(true)} style={{ whiteSpace: "nowrap" }}>
            + 방 만들기
          </button>
        </div>
        {err && (
          <div style={{ color: "#fca5a5", fontSize: 13, marginTop: 8 }}>{err}</div>
        )}
      </div>

      {/* Section header */}
      <div className="row" style={{ justifyContent: "space-between", padding: "0 2px" }}>
        <div className="row" style={{ gap: 8 }}>
          <h2 style={{ fontSize: 18 }}>공개 방</h2>
          <span className="badge badge-muted">{rooms.length}</span>
        </div>
        <span className="muted" style={{ fontSize: 12 }}>5초마다 자동 갱신</span>
      </div>

      {/* Room grid */}
      {rooms.length === 0 ? (
        <div
          className="card"
          style={{
            textAlign: "center",
            padding: "48px 24px",
            borderRadius: "var(--radius-lg)",
            borderStyle: "dashed",
          }}
        >
          <div style={{ fontSize: 36, marginBottom: 12 }}>🎮</div>
          <div style={{ fontWeight: 600, marginBottom: 8 }}>공개 방이 없어요</div>
          <div className="muted">방을 만들거나 코드로 입장하세요</div>
        </div>
      ) : (
        <div className="rooms-grid">
          {rooms.map((r, i) => (
            <RoomCard key={r.id} room={r} style={{ animationDelay: `${i * 50}ms` }} />
          ))}
        </div>
      )}

      {showCreate && (
        <CreateRoomModal categories={cats} onClose={() => setShowCreate(false)} />
      )}
    </div>
  );
}

function RoomCard({ room: r, style }: { room: RoomListItem; style?: React.CSSProperties }) {
  const pct = Math.round((r.player_count / r.max_players) * 100);
  const full = r.player_count >= r.max_players;
  const playing = r.status === "playing";

  return (
    <Link
      to={`/rooms/${r.id}`}
      className="card card-hover anim-fade-up"
      style={{ borderRadius: "var(--radius-lg)", padding: "16px 18px", ...style }}
    >
      <div className="row" style={{ justifyContent: "space-between", marginBottom: 10 }}>
        <span style={{ fontWeight: 700, fontSize: 15, flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {r.name}
        </span>
        <span className="code-badge" style={{ fontSize: 12, letterSpacing: 2, flexShrink: 0 }}>
          {r.code}
        </span>
      </div>

      <div className="row" style={{ marginBottom: 10, gap: 6 }}>
        {playing ? (
          <span className="badge badge-warn">🎮 진행중</span>
        ) : (
          <span className="badge badge-accent">⏳ 대기중</span>
        )}
        {full && <span className="badge badge-muted">만원</span>}
        <span className="muted" style={{ marginLeft: "auto" }}>선 {r.win_score}점</span>
      </div>

      {/* Player count bar */}
      <div>
        <div className="row" style={{ justifyContent: "space-between", marginBottom: 5 }}>
          <span className="muted" style={{ fontSize: 12 }}>플레이어</span>
          <span style={{ fontSize: 12, fontWeight: 600, color: full ? "var(--warn)" : "var(--text-muted)" }}>
            {r.player_count} / {r.max_players}
          </span>
        </div>
        <div className="progress-track">
          <div
            className="progress-bar"
            style={{
              width: `${pct}%`,
              background: full ? "var(--grad-danger)" : playing ? "var(--grad-accent)" : "var(--grad-primary)",
            }}
          />
        </div>
      </div>
    </Link>
  );
}

function CreateRoomModal({ categories, onClose }: { categories: string[]; onClose: () => void }) {
  const nav = useNavigate();
  const [name, setName] = useState("");
  const [isPublic, setIsPublic] = useState(true);
  const [winScore, setWinScore] = useState(20);
  const [roundSeconds, setRoundSeconds] = useState(30);
  const [maxPlayers, setMaxPlayers] = useState(8);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => { inputRef.current?.focus(); }, []);

  function toggle(cat: string) {
    setSelected((s) => {
      const n = new Set(s);
      n.has(cat) ? n.delete(cat) : n.add(cat);
      return n;
    });
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    setBusy(true);
    setErr(null);
    try {
      const r = await roomsApi.create({
        name: name.trim(),
        is_public: isPublic,
        win_score: winScore,
        round_seconds: roundSeconds,
        max_players: maxPlayers,
        categories: [...selected],
      });
      nav(`/rooms/${r.id}`);
    } catch (e: any) {
      setErr(e.message);
      setBusy(false);
    }
  }

  return (
    <div className="modal-overlay anim-fade-in" onClick={onClose}>
      <form
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
        className="modal-box stack"
      >
        <div className="row" style={{ justifyContent: "space-between" }}>
          <h3>방 만들기</h3>
          <button type="button" className="btn-ghost btn-sm" onClick={onClose} style={{ fontSize: 18, padding: "2px 8px" }}>×</button>
        </div>

        <div className="col" style={{ gap: 6 }}>
          <label className="muted" style={{ fontSize: 13, fontWeight: 600 }}>방 제목</label>
          <input
            ref={inputRef}
            placeholder="예: 우리반 퀴즈왕"
            value={name}
            onChange={(e) => setName(e.target.value)}
            maxLength={40}
          />
        </div>

        {/* Settings grid */}
        <div className="col" style={{ gap: 8 }}>
          <label className="muted" style={{ fontSize: 13, fontWeight: 600 }}>게임 설정</label>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            <NumberField label="목표 점수" value={winScore} onChange={setWinScore} min={3} max={100} />
            <NumberField label="라운드 시간(초)" value={roundSeconds} onChange={setRoundSeconds} min={10} max={120} />
            <NumberField label="최대 인원" value={maxPlayers} onChange={setMaxPlayers} min={2} max={30} />
            <label style={{ display: "flex", alignItems: "center", gap: 8, cursor: "pointer", fontSize: 14 }}>
              <input
                type="checkbox"
                checked={isPublic}
                onChange={(e) => setIsPublic(e.target.checked)}
                style={{ width: 16, height: 16, minHeight: 0, accentColor: "var(--primary)" }}
              />
              공개 방
            </label>
          </div>
        </div>

        {/* Categories */}
        {categories.length > 0 && (
          <div className="col" style={{ gap: 8 }}>
            <div className="row" style={{ justifyContent: "space-between" }}>
              <label className="muted" style={{ fontSize: 13, fontWeight: 600 }}>카테고리</label>
              {selected.size > 0 && (
                <span style={{ fontSize: 12, color: "var(--primary-light)" }}>{selected.size}개 선택</span>
              )}
            </div>
            <div className="row wrap" style={{ gap: 6 }}>
              {categories.map((c) => (
                <button
                  key={c}
                  type="button"
                  className={`tag-btn ${selected.has(c) ? "tag-btn-on" : ""}`}
                  onClick={() => toggle(c)}
                >
                  {c}
                </button>
              ))}
            </div>
            {selected.size === 0 && (
              <div className="muted" style={{ fontSize: 12 }}>선택 안 하면 전체 카테고리</div>
            )}
          </div>
        )}

        {err && (
          <div style={{ color: "#fca5a5", fontSize: 13 }}>{err}</div>
        )}

        <div className="row" style={{ justifyContent: "flex-end", gap: 8 }}>
          <button type="button" className="btn-ghost" onClick={onClose}>취소</button>
          <button type="submit" disabled={busy || !name.trim()}>
            {busy ? "생성 중..." : "방 만들기"}
          </button>
        </div>
      </form>
    </div>
  );
}

function NumberField({
  label, value, onChange, min, max,
}: {
  label: string; value: number; onChange: (v: number) => void; min: number; max: number;
}) {
  return (
    <div className="col" style={{ gap: 4 }}>
      <label style={{ fontSize: 12, color: "var(--text-muted)", fontWeight: 600 }}>{label}</label>
      <input
        type="number"
        min={min}
        max={max}
        value={value}
        onChange={(e) => onChange(+e.target.value)}
        style={{ minHeight: 36, fontSize: 14 }}
      />
    </div>
  );
}
