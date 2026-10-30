import {
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type FormEvent,
  type MouseEvent as ReactMouseEvent,
  type PointerEvent as ReactPointerEvent,
} from "react";
import { useNavigate } from "react-router-dom";
import { Avatar } from "../../components/Avatar";
import { confirmDialog } from "../../components/feedback";
import { Icon } from "../../components/icons";
import { InviteBox } from "../../components/InviteBox";
import { PlayersSheet } from "../../components/PlayersSheet";
import { SafetySheet, type SafetyTarget } from "../../components/SafetySheet";
import { copyCode } from "../../lib/share";
import { useVisualViewport } from "../../lib/useVisualViewport";
import { isHidden, useBlocked } from "../../store/blocked";
import type { ChatRow, PlayerRow, RoomApi, RoundState } from "./useRoom";

type Sheet = "players" | "invite" | null;

/**
 * The game screen, laid out like a KakaoTalk chat room: the question sits in a small pinned
 * notice at the top and the rest of the screen is the chat. Scores live behind the people
 * button (and in a side panel on wide screens) instead of taking rows away from the chat.
 */
export function RoomGame({ r }: { r: RoomApi }) {
  const nav = useNavigate();
  const meId = r.user?.user_id ?? "";
  const [sheet, setSheet] = useState<Sheet>(null);
  const [text, setText] = useState("");
  const [showJump, setShowJump] = useState(false);
  const [safety, setSafety] = useState<SafetyTarget | null>(null);
  const logRef = useRef<HTMLDivElement>(null);
  const stick = useRef(true);

  // The server already withholds blocked players' new chat lines; this also hides the ones that
  // reached the screen before the block.
  const blockedAt = useBlocked((s) => s.at);
  useEffect(() => {
    void useBlocked.getState().load();
  }, []);
  const chat = r.chat.filter((c) => !(c.kind === "chat" && isHidden(blockedAt, c.user_id, c.ts)));

  useVisualViewport();
  // the frame is pinned to the visible viewport; the page itself must never scroll
  useEffect(() => {
    document.body.classList.add("lock-scroll");
    return () => document.body.classList.remove("lock-scroll");
  }, []);

  // Follow the NEWEST line, not the line count: the log keeps only the last few hundred rows,
  // so once it is full its length never changes again and a length-keyed effect would stop
  // scrolling for good (the view then drifts away from the newest line and the "latest" button
  // never goes away). Ids only ever grow.
  const lastChatId = chat.length ? chat[chat.length - 1].id : 0;
  useLayoutEffect(() => {
    const el = logRef.current;
    if (el && stick.current) el.scrollTop = el.scrollHeight;
  }, [lastChatId]);

  // The on-screen keyboard, rotation or a banner changes the log's height: stay glued to the
  // newest line while the player has not scrolled up.
  useEffect(() => {
    const el = logRef.current;
    if (!el || typeof ResizeObserver === "undefined") return;
    const ro = new ResizeObserver(() => {
      if (stick.current) el.scrollTop = el.scrollHeight;
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  function onLogScroll() {
    const el = logRef.current;
    if (!el) return;
    const near = el.scrollHeight - el.scrollTop - el.clientHeight < 60;
    stick.current = near;
    setShowJump(!near);
  }
  function jumpToLatest() {
    const el = logRef.current;
    if (el) el.scrollTop = el.scrollHeight;
    stick.current = true;
    setShowJump(false);
  }

  function submit(e: FormEvent) {
    e.preventDefault();
    const v = text.trim();
    if (!v || !r.connected) return;
    r.sendChat(v);
    setText("");
    stick.current = true; // your own message should always be visible
  }

  async function leave() {
    if (r.status === "playing") {
      const ok = await confirmDialog({
        title: "게임에서 나갈까요?",
        content: "진행 중인 게임에서 나가요. 같은 방 코드로 다시 들어올 수 있어요.",
        confirmLabel: "나가기",
      });
      if (!ok) return;
    }
    nav("/home");
  }

  async function kick(userId: string) {
    const p = r.players.find((x) => x.user_id === userId);
    if (await confirmDialog({ title: "강퇴할까요?", content: `${p?.nickname ?? "이 참가자"}님을 이 방에서 내보내요.`, confirmLabel: "강퇴" })) {
      r.kick(userId);
    }
  }

  // people who left stay on the board only while they hold points
  const ranked = r.players.filter((p) => p.online !== false || p.score > 0).sort((a, b) => b.score - a.score);
  const onlineCount = r.livePlayers.length;
  const roundOver = !!r.round?.ended;
  const myScore = r.players.find((p) => p.user_id === meId)?.score ?? 0;

  return (
    <div className="game">
      <header className="game-bar">
        <button className="icon-btn" aria-label="나가기" onClick={leave}>
          <Icon name="back" />
        </button>
        <div className="game-bar__title">
          <div className="game-bar__round">{r.roomName || "게임"}</div>
          <div className="game-bar__sub">
            {r.round ? `라운드 ${r.round.round} · ` : ""}내 점수 <b>{myScore}</b> / {r.winScore}
          </div>
        </div>
        {r.roomCode ? (
          <button className="code-chip mono" onClick={() => copyCode(r.roomCode)} aria-label={`방 코드 ${r.roomCode} 복사`}>
            {r.roomCode}
          </button>
        ) : null}
        <button className="icon-btn icon-btn--count" aria-label="참가자와 점수" onClick={() => setSheet("players")}>
          <Icon name="people" size={22} />
          <span className="count-badge">{onlineCount}</span>
        </button>
        <button className="icon-btn" aria-label="초대 링크 공유" onClick={() => setSheet("invite")}>
          <Icon name="link" size={22} />
        </button>
        <button
          className="skip-btn"
          aria-label="문제 건너뛰기"
          disabled={!r.round || roundOver || !r.connected}
          onClick={() => r.skip()}
        >
          <Icon name="skip" size={20} />
          <span>{r.skipState && !roundOver ? `스킵 ${r.skipState.votes}/${r.skipState.needed}` : "스킵"}</span>
        </button>
      </header>

      {!r.connected ? <div className="conn-banner">연결이 끊겼습니다. 재연결 중...</div> : null}

      <div className="game-body">
        <div className="game-main">
          <QuestionNotice round={r.round} roundSeconds={r.roundSeconds} playing={r.status === "playing"} />

          <div className="chat-wrap">
            <div className="chat-log" ref={logRef} onScroll={onLogScroll} role="log" aria-live="polite">
              {chat.length === 0 ? (
                <div className="chat-empty">
                  채팅창에 정답을 입력해 보세요!
                  <br />
                  ‘스킵’이나 ‘ㅅㅋ’를 치면 건너뛰기 투표예요
                </div>
              ) : null}
              {chat.map((c, i) => (
                <Message
                  key={c.id}
                  c={c}
                  me={c.user_id === meId}
                  first={!sameRun(chat[i - 1], c)}
                  last={!sameRun(c, chat[i + 1])}
                  onUser={(line) => c.user_id && setSafety({ user_id: c.user_id, nickname: c.nickname, message: line })}
                />
              ))}
            </div>
            {showJump ? (
              <button className="jump-btn" onClick={jumpToLatest}>
                ↓ 최신 메시지
              </button>
            ) : null}
          </div>

          <form className="chat-bar" onSubmit={submit}>
            <input
              className="chat-bar__input"
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="정답이나 메시지를 입력하세요"
              enterKeyHint="send"
              autoComplete="off"
              autoCorrect="off"
              autoCapitalize="off"
              spellCheck={false}
              maxLength={200}
              aria-label="메시지 또는 정답 입력"
            />
            <button
              className="chat-bar__send"
              type="submit"
              aria-label="보내기"
              disabled={!text.trim() || !r.connected}
              onMouseDown={(e) => e.preventDefault()} // keep the keyboard open on iPhone
            >
              <Icon name="send" size={20} />
            </button>
          </form>
        </div>

        <aside className="board-side" aria-label="참가자 점수">
          <div className="board-side__title">🏆 점수판</div>
          <div className="col" style={{ gap: 8 }}>
            {ranked.map((p, i) => (
              <SideRow key={p.user_id} p={p} rank={i + 1} me={p.user_id === meId} win={r.winScore} owner={p.user_id === r.ownerId} />
            ))}
          </div>
          <InviteBox code={r.roomCode} />
        </aside>
      </div>

      {sheet === "players" ? (
        <PlayersSheet
          players={ranked}
          ownerId={r.ownerId}
          meId={meId}
          canKick={r.isOwner && r.status !== "playing"}
          roomCode={r.roomCode}
          onKick={kick}
          onUser={(p) => {
            setSheet(null);
            setSafety({ user_id: p.user_id, nickname: p.nickname });
          }}
          onClose={() => setSheet(null)}
        />
      ) : null}
      {safety ? <SafetySheet target={safety} roomCode={r.roomCode} onClose={() => setSafety(null)} /> : null}
      {sheet === "invite" ? (
        <div className="backdrop backdrop--sheet" onClick={() => setSheet(null)}>
          <div className="sheet" role="dialog" aria-label="친구 초대" onClick={(e) => e.stopPropagation()}>
            <div className="sheet__grip" />
            <InviteBox code={r.roomCode} />
          </div>
        </div>
      ) : null}
    </div>
  );
}

// ── question (the pinned "notice") ──────────────────────────────────────────

function QuestionNotice({ round, roundSeconds, playing }: { round: RoundState | null; roundSeconds: number; playing: boolean }) {
  if (!round) {
    return (
      <section className="q-notice q-notice--wait">
        <span className="spinner spinner--sm" /> {playing ? "다음 문제 준비 중..." : "게임을 준비하고 있어요..."}
      </section>
    );
  }
  const ended = round.ended;
  return (
    <section className={`q-notice ${ended ? "is-ended" : ""}`}>
      <div className="q-notice__meta">
        <span className="q-notice__no">Q{round.round}</span>
        <span className="q-chip">{round.category}</span>
        <span className="grow" />
        {!ended ? <Countdown deadline={round.deadline_ts} /> : null}
      </div>

      <div className="q-card__prompt q-notice__prompt">{round.prompt}</div>

      {round.hint && !ended ? <div className="q-notice__hint">💡 힌트 · {round.hint}</div> : null}

      {ended ? (
        <div className={`q-notice__result q-notice__result--${ended.reason}`}>
          {ended.reason === "correct"
            ? `🎉 ${ended.nickname}님 정답! → ${ended.answer}`
            : ended.reason === "skipped"
              ? `⏭️ 건너뛰었어요 — 정답: ${ended.answer}`
              : `⌛ 시간 초과 — 정답: ${ended.answer}`}
          <NextCountdown />
        </div>
      ) : (
        <TimeBar deadline={round.deadline_ts} total={roundSeconds} />
      )}
    </section>
  );
}

// The server pauses 3 s between questions. Mounted only while a round is over, so it restarts
// for every round and disappears the moment the next question arrives.
function NextCountdown({ seconds = 3 }: { seconds?: number }) {
  const [left, setLeft] = useState(seconds);
  useEffect(() => {
    const t = setInterval(() => setLeft((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(t);
  }, []);
  return <div className="q-notice__next">{left > 0 ? `다음 문제까지 ${left}초...` : "곧 시작돼요!"}</div>;
}

function useNow(active: boolean, every = 200): number {
  const [now, setNow] = useState(() => Date.now() / 1000);
  useEffect(() => {
    if (!active) return;
    setNow(Date.now() / 1000);
    const id = setInterval(() => setNow(Date.now() / 1000), every);
    return () => clearInterval(id);
  }, [active, every]);
  return now;
}

function Countdown({ deadline }: { deadline: number }) {
  const now = useNow(true, 250);
  const remain = Math.max(0, Math.ceil(deadline - now));
  return (
    <span className={`q-notice__time ${remain <= 5 ? "is-urgent" : ""}`} aria-label={`${remain}초 남음`}>
      ⏱ {remain}초
    </span>
  );
}

function TimeBar({ deadline, total }: { deadline: number; total: number }) {
  const now = useNow(true);
  const remain = Math.max(0, deadline - now);
  const full = Math.max(total || 30, remain);
  const pct = Math.min(100, (remain / full) * 100);
  return (
    <div className="q-notice__bar" aria-hidden>
      <i style={{ width: `${pct}%` }} className={pct < 25 ? "is-urgent" : ""} />
    </div>
  );
}

// ── scores (wide screens only) ──────────────────────────────────────────────

const MEDAL = ["🥇", "🥈", "🥉"];

function SideRow({ p, rank, me, win, owner }: { p: PlayerRow; rank: number; me: boolean; win: number; owner: boolean }) {
  const pct = Math.min(100, Math.round((p.score / Math.max(1, win)) * 100));
  return (
    <div className={`side-row ${me ? "is-me" : ""} ${p.online === false ? "is-off" : ""}`}>
      <span className="side-row__rank">{rank <= 3 ? MEDAL[rank - 1] : rank}</span>
      <Avatar name={p.nickname} size="sm" crown={owner} online={p.online !== false} />
      <div className="grow side-row__mid">
        <div className="side-row__name">
          {p.nickname}
          {me ? <span className="muted"> (나)</span> : null}
        </div>
        <div className="progress">
          <i style={{ width: `${pct}%` }} />
        </div>
      </div>
      <span className="side-row__score">{p.score}</span>
    </div>
  );
}

// ── chat (KakaoTalk-style) ──────────────────────────────────────────────────

function hhmm(ts: number): string {
  const d = new Date(ts);
  const h = d.getHours();
  const period = h < 12 ? "오전" : "오후";
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${period} ${h12}:${String(d.getMinutes()).padStart(2, "0")}`;
}

/** Same sender, same minute, nothing in between: one "run" (name/photo once, time once). */
function sameRun(a: ChatRow | undefined, b: ChatRow | undefined): boolean {
  return !!a && !!b && a.kind === "chat" && b.kind === "chat" && a.user_id === b.user_id && hhmm(a.ts) === hhmm(b.ts);
}

/** Long-press (≈0.5 s) without moving opens the menu, like KakaoTalk. */
function useLongPress(onLong: () => void) {
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const start = useRef<{ x: number; y: number } | null>(null);
  const clear = () => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = null;
    start.current = null;
  };
  return {
    onPointerDown: (e: ReactPointerEvent) => {
      start.current = { x: e.clientX, y: e.clientY };
      timer.current = setTimeout(() => {
        clear();
        onLong();
      }, 500);
    },
    onPointerMove: (e: ReactPointerEvent) => {
      if (start.current && Math.hypot(e.clientX - start.current.x, e.clientY - start.current.y) > 10) clear();
    },
    onPointerUp: clear,
    onPointerLeave: clear,
    onPointerCancel: clear,
    onContextMenu: (e: ReactMouseEvent) => {
      e.preventDefault();
      clear();
      onLong();
    },
  };
}

function Message({ c, me, first, last, onUser }: { c: ChatRow; me: boolean; first: boolean; last: boolean; onUser: (line: string) => void }) {
  const press = useLongPress(() => onUser(c.text));
  if (c.kind === "system") {
    const good = c.text.startsWith("✅");
    return (
      <div className="msg-sys">
        <span className={good ? "is-good" : ""}>{c.text}</span>
      </div>
    );
  }
  if (me) {
    return (
      <div className={`msg msg--me ${first ? "is-first" : ""}`}>
        <div className="msg__line">
          {last ? <span className="msg__time">{hhmm(c.ts)}</span> : null}
          <div className="msg__bubble">{c.text}</div>
        </div>
      </div>
    );
  }
  return (
    <div className={`msg ${first ? "is-first" : "is-cont"}`}>
      {first && c.user_id ? (
        <button className="msg__avatar" aria-label={`${c.nickname}님 신고·차단`} onClick={() => onUser(c.text)}>
          <Avatar name={c.nickname} size="sm" />
        </button>
      ) : (
        <span className="msg__avatar-gap" aria-hidden />
      )}
      <div className="msg__col">
        {first ? <div className="msg__name">{c.nickname}</div> : null}
        <div className="msg__line">
          <div className="msg__bubble" {...(c.user_id ? press : {})}>
            {c.text}
          </div>
          {last ? <span className="msg__time">{hhmm(c.ts)}</span> : null}
        </div>
      </div>
    </div>
  );
}
