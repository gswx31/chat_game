import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Avatar } from "../../components/Avatar";
import { confirmDialog } from "../../components/feedback";
import { Icon } from "../../components/icons";
import { InviteBox } from "../../components/InviteBox";
import { SafetySheet, type SafetyTarget } from "../../components/SafetySheet";
import { copyCode } from "../../lib/share";
import type { RoomApi } from "./useRoom";

/** Waiting room — the app's lobby screen (+ the invite box). */
export function RoomLobby({ r }: { r: RoomApi }) {
  const nav = useNavigate();
  const meId = r.user?.user_id ?? "";
  const [safety, setSafety] = useState<SafetyTarget | null>(null);

  async function kick(userId: string, name: string) {
    if (await confirmDialog({ title: "강퇴할까요?", content: `${name}님을 이 방에서 내보내요.`, confirmLabel: "강퇴" })) {
      r.kick(userId);
    }
  }

  return (
    <div className="app-page lobby">
      <header className="lobby-head">
        <div className="lobby-head__row">
          <button className="icon-btn" aria-label="나가기" onClick={() => nav("/home")}>
            <Icon name="back" />
          </button>
          <h1 className="lobby-head__title">{r.roomName || "방"}</h1>
          <span className={`status-dot ${r.connected ? "is-on" : ""}`} title={r.connected ? "연결됨" : "연결 중"} />
        </div>
        <div className="lobby-head__chips">
          <span className="head-chip">선 {r.winScore}점</span>
          <span className="head-chip">{r.roundSeconds}초/라운드</span>
          {r.roomCode ? (
            <button className="head-chip head-chip--btn" onClick={() => copyCode(r.roomCode)}>
              🔑 <b className="mono">{r.roomCode}</b> <Icon name="copy" size={14} />
            </button>
          ) : null}
        </div>
      </header>

      {!r.connected && r.synced ? <div className="conn-banner">연결이 끊겼습니다. 재연결 중...</div> : null}

      <div className="lobby-count">
        <span className="lobby-count__label">
          <Icon name="people" size={22} color="var(--primary)" /> 참가자 {r.livePlayers.length}명
        </span>
        {r.isOwner ? <span className="badge">방장</span> : null}
      </div>

      <div className="page-body lobby-body">
        <div className="player-grid">
          {r.livePlayers.map((p) => {
            const me = p.user_id === meId;
            return (
              <div key={p.user_id} className={`player-card ${me ? "is-me" : ""} ${p.online === false ? "is-off" : ""}`}>
                <Avatar name={p.nickname} size="lg" crown={p.user_id === r.ownerId} />
                <div className="player-card__name">{p.nickname}</div>
                {me ? <div className="player-card__me">나</div> : null}
                {!me && p.online !== false ? (
                  <button className="player-card__more" aria-label={`${p.nickname}님 신고·차단`} onClick={() => setSafety(p)}>
                    ⋯
                  </button>
                ) : null}
                {r.isOwner && !me && p.online !== false ? (
                  <button className="player-card__kick" onClick={() => kick(p.user_id, p.nickname)}>
                    강퇴
                  </button>
                ) : null}
              </div>
            );
          })}
        </div>

        <InviteBox code={r.roomCode} />
      </div>

      {safety ? <SafetySheet target={safety} roomCode={r.roomCode} onClose={() => setSafety(null)} /> : null}

      <div className="bottom-bar">
        {r.isOwner ? (
          <button className="btn btn--block" disabled={!r.connected} onClick={() => r.startGame()}>
            <Icon name="play" size={22} /> 게임 시작 🎮
          </button>
        ) : (
          <div className="wait-note">
            <span className="spinner spinner--sm" /> 방장이 게임을 시작하길 기다리는 중...
          </div>
        )}
      </div>
    </div>
  );
}
