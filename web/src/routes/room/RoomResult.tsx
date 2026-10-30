import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Avatar } from "../../components/Avatar";
import { Icon } from "../../components/icons";
import type { PlayerRow, RoomApi } from "./useRoom";

const MEDAL = ["🥇", "🥈", "🥉"];

/** Final ranking — the app's result screen (podium + full list + rematch). */
export function RoomResult({ r }: { r: RoomApi }) {
  const nav = useNavigate();
  const [asked, setAsked] = useState(false);
  const scores: PlayerRow[] = (r.finalResult?.scores ?? r.players)
    .filter((p) => p.online !== false || p.score > 0) // someone who left without scoring is just noise
    .sort((a, b) => b.score - a.score);
  const meId = r.user?.user_id ?? "";

  // podium order: 2nd, 1st, 3rd (like the app)
  const top = scores.slice(0, 3);
  const podium = [top[1], top[0], top[2]].map((p, i) => (p ? { p, place: [2, 1, 3][i] } : null));

  return (
    <div className="result">
      <div className="result__hero">
        <div className="result__confetti">🎉</div>
        <h1 className="result__title">게임 종료!</h1>
        <div className="result__sub">최종 순위</div>

        <div className="podium">
          {podium.map((slot, i) =>
            slot ? (
              <div key={slot.p.user_id} className={`podium__col podium__col--${slot.place}`}>
                <div className="podium__medal">{MEDAL[slot.place - 1]}</div>
                <Avatar name={slot.p.nickname} size={slot.place === 1 ? "lg" : "md"} onBrand />
                <div className="podium__name">{slot.p.nickname}</div>
                <div className="podium__score">{slot.p.score}점</div>
                <div className="podium__bar">{slot.place}</div>
              </div>
            ) : (
              <div key={`empty-${i}`} className="podium__col" />
            )
          )}
        </div>
      </div>

      <div className="result__sheet">
        <h2 className="result__sheet-title">전체 순위</h2>
        <div className="col" style={{ gap: 10 }}>
          {scores.map((p, i) => (
            <div key={p.user_id} className={`rank-row ${i < 3 ? "is-top" : ""} ${p.user_id === meId ? "is-me" : ""}`}>
              <span className="rank-row__rank">{i < 3 ? MEDAL[i] : `${i + 1}위`}</span>
              <Avatar name={p.nickname} size="sm" />
              <span className="rank-row__name">
                {p.nickname}
                {p.user_id === meId ? <span className="muted"> (나)</span> : null}
              </span>
              <span className={`rank-row__score ${i < 3 ? "is-top" : ""}`}>{p.score}점</span>
            </div>
          ))}
        </div>

        <div className="result__actions">
          {r.isOwner ? (
            <button
              className="btn btn--accent btn--block"
              disabled={!r.connected || asked}
              onClick={() => {
                setAsked(true);
                r.rematch();
              }}
            >
              <Icon name="refresh" size={22} /> {asked ? "다시 시작 중..." : "다시 하기 🎮"}
            </button>
          ) : (
            <div className="wait-note">
              <span className="spinner spinner--sm" /> 방장이 다시 시작하길 기다리는 중...
            </div>
          )}
          <button className="btn btn--block" onClick={() => nav("/home")}>
            <Icon name="home" size={22} /> 메인으로 돌아가기
          </button>
        </div>
      </div>
    </div>
  );
}
