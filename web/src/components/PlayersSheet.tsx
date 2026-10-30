import { Avatar } from "./Avatar";
import { InviteBox } from "./InviteBox";
import type { PlayerRow } from "../routes/room/useRoom";
import "../styles/safety.css";

interface Props {
  players: PlayerRow[];
  ownerId: string | null;
  meId: string;
  canKick: boolean;
  roomCode: string;
  onKick: (userId: string) => void;
  /** open the report / block sheet for a player */
  onUser?: (p: PlayerRow) => void;
  onClose: () => void;
}

/** Bottom sheet: who is in the room (+ kick for the owner, report / block) and the invite box. */
export function PlayersSheet({ players, ownerId, meId, canKick, roomCode, onKick, onUser, onClose }: Props) {
  return (
    <div className="backdrop backdrop--sheet" onClick={onClose}>
      <div className="sheet" role="dialog" aria-label="참가자" onClick={(e) => e.stopPropagation()}>
        <div className="sheet__grip" />
        <div className="section-head__title" style={{ margin: "0 4px 10px" }}>
          참가자 {players.length}명
        </div>
        <div className="col" style={{ gap: 0 }}>
          {players.map((p) => (
            <div key={p.user_id} className="sheet-row">
              <Avatar name={p.nickname} crown={p.user_id === ownerId} online={p.online !== false} />
              <div className="grow">
                <div className="sheet-row__name">
                  {p.nickname}
                  {p.user_id === meId ? <span className="muted"> (나)</span> : null}
                </div>
              </div>
              <span className="pill">{p.score}점</span>
              {canKick && p.user_id !== meId && p.online !== false ? (
                <button className="btn btn--sm btn--ghost" style={{ color: "var(--danger)" }} onClick={() => onKick(p.user_id)}>
                  강퇴
                </button>
              ) : null}
              {onUser && p.user_id !== meId ? (
                <button className="sheet-row__more" aria-label={`${p.nickname}님 신고·차단`} onClick={() => onUser(p)}>
                  ⋯
                </button>
              ) : null}
            </div>
          ))}
        </div>
        <div style={{ marginTop: 14 }}>
          <InviteBox code={roomCode} />
        </div>
      </div>
    </div>
  );
}
