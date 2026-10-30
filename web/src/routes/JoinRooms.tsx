import { useCallback, useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { friendlyError, roomsApi, type RoomListItem } from "../api/client";
import { AppBar } from "../components/AppBar";
import { toast } from "../components/feedback";
import { Icon } from "../components/icons";
import { roomPath } from "../lib/paths";

/** Join a room: type a 6-letter code or pick one of the public rooms. `?code=1` (the home
 * screen's "코드로 참가") puts the cursor in the code box straight away. */
export default function JoinRooms() {
  const nav = useNavigate();
  const [params] = useSearchParams();
  const codeRef = useRef<HTMLInputElement>(null);
  const [rooms, setRooms] = useState<RoomListItem[] | null>(null);
  const [loadErr, setLoadErr] = useState(false);
  const [keyword, setKeyword] = useState("");
  const [code, setCode] = useState("");
  const [joining, setJoining] = useState(false);

  const load = useCallback(async () => {
    try {
      setRooms(await roomsApi.list());
      setLoadErr(false);
    } catch {
      setLoadErr(true);
    }
  }, []);

  useEffect(() => {
    if (params.has("code")) codeRef.current?.focus();
  }, [params]);

  // the list is live data: refresh while the screen is open
  useEffect(() => {
    load();
    const t = setInterval(() => {
      if (document.visibilityState === "visible") load();
    }, 6000);
    return () => clearInterval(t);
  }, [load]);

  async function joinByCode() {
    const c = code.trim().toUpperCase();
    if (c.length !== 6) {
      toast("방코드는 6자리예요");
      return;
    }
    setJoining(true);
    try {
      const room = await roomsApi.getByCode(c);
      if (room.status === "ended") {
        toast("이미 종료된 방이에요");
        return;
      }
      nav(roomPath(room.id));
    } catch (e) {
      toast(e instanceof TypeError ? friendlyError(e) : "해당 코드의 방을 찾을 수 없어요", "error");
    } finally {
      setJoining(false);
    }
  }

  function open(r: RoomListItem) {
    if (r.status === "ended") {
      toast("이미 종료된 방이에요");
      return;
    }
    nav(roomPath(r.id));
  }

  const kw = keyword.trim().toLowerCase();
  const filtered = (rooms ?? []).filter((r) => !kw || r.name.toLowerCase().includes(kw) || r.code.toLowerCase().includes(kw));

  return (
    <div className="app-page">
      <AppBar title="방 참가하기" back="/home" />

      <div className="join-head">
        <form
          className="card join-codecard"
          onSubmit={(e) => {
            e.preventDefault();
            joinByCode();
          }}
        >
          <div className="join-codecard__title">
            <span className="join-codecard__icon" aria-hidden>
              <Icon name="login" size={20} />
            </span>
            친구에게 받은 방코드로 입장
          </div>
          <div className="join-code">
            <input
              ref={codeRef}
              className="join-input join-input--code mono"
              placeholder="방코드 6자리"
              value={code}
              maxLength={6}
              autoCapitalize="characters"
              autoCorrect="off"
              spellCheck={false}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              aria-label="방코드"
            />
            <button className="join-go" type="submit" disabled={joining}>
              {joining ? <span className="spinner spinner--sm spinner--onbrand" style={{ margin: 0 }} /> : "입장"}
            </button>
          </div>
        </form>
        <div className="join-field">
          <span className="join-field__icon" aria-hidden>
            <Icon name="search" size={20} />
          </span>
          <input
            className="join-input"
            placeholder="공개방 이름으로 검색..."
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            aria-label="방 이름으로 검색"
          />
        </div>
      </div>

      <div className="page-body">
        <div className="join-sec">
          <span>지금 열려 있는 공개방</span>
          {rooms ? <span className="badge badge--soft">{filtered.length}개</span> : null}
        </div>
        {rooms === null && !loadErr ? (
          <div className="spinner" />
        ) : loadErr && rooms === null ? (
          <div className="empty">
            <div className="empty__icon">📡</div>
            <div className="empty__title">서버에 연결할 수 없어요</div>
            <button className="btn btn--sm btn--soft" onClick={load}>
              <Icon name="refresh" size={18} /> 다시 시도
            </button>
          </div>
        ) : filtered.length === 0 ? (
          <div className="empty">
            <div className="empty__icon">🚪</div>
            <div className="empty__title">참가 가능한 방이 없어요</div>
            <div className="empty__text">직접 방을 만들어보세요!</div>
          </div>
        ) : (
          <div className="list">
            {filtered.map((r) => {
              const playing = r.status === "playing";
              const pct = Math.min(100, Math.round((r.player_count / Math.max(1, r.max_players)) * 100));
              const full = r.player_count >= r.max_players;
              return (
                <button key={r.id} className="list-tile room-tile" onClick={() => open(r)}>
                  <span className={`icon-box icon-box--lg ${playing ? "icon-box--accent" : "icon-box--primary"}`}>
                    <Icon name={playing ? "play" : "people"} size={28} />
                  </span>
                  <span className="list-tile__body">
                    <span className="room-tile__top">
                      <span className="list-tile__title">{r.name}</span>
                      <span className={`badge ${playing ? "badge--green" : ""}`}>{playing ? "진행중" : "대기중"}</span>
                    </span>
                    <span className="room-tile__meta">
                      <span className="mono room-tile__code">코드: {r.code}</span>
                      <span className="muted">선 {r.win_score}점</span>
                    </span>
                    <span className="room-tile__bar">
                      <span className="progress grow">
                        <i style={{ width: `${pct}%`, background: full ? "var(--danger)" : undefined }} />
                      </span>
                      <span className="room-tile__count" style={full ? { color: "var(--danger)" } : undefined}>
                        {r.player_count}/{r.max_players}
                      </span>
                    </span>
                  </span>
                  <span className="list-tile__chev">
                    <Icon name="chevron" size={24} />
                  </span>
                </button>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
