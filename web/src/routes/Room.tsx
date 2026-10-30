import { useNavigate, useParams } from "react-router-dom";
import { AppBar } from "../components/AppBar";
import { RoomGame } from "./room/RoomGame";
import { RoomLobby } from "./room/RoomLobby";
import { RoomResult } from "./room/RoomResult";
import { useRoom } from "./room/useRoom";

/**
 * One route for the whole life of a room (`/room/:roomId`): the server's room status decides
 * whether the player sees the lobby, the game or the result — same flow as the app's
 * lobby → game → result screens, and a refresh or a re-connect lands on the right one.
 */
export default function Room() {
  const { roomId } = useParams();
  const nav = useNavigate();
  const r = useRoom(roomId);

  // Closed for good (kicked, room gone, full, sealed): say why and offer the way out.
  if (r.closeMsg) {
    return (
      <div className="app-page">
        <AppBar title="방" back="/home" />
        <div className="page-body">
          <div className="empty">
            <div className="empty__icon">😕</div>
            <div className="empty__title">입장할 수 없어요</div>
            <div className="empty__text">{r.closeMsg}</div>
            <button className="btn" onClick={() => nav("/home", { replace: true })}>
              메인으로 돌아가기
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Waiting for the first snapshot from the server.
  if (!r.synced) {
    return (
      <div className="app-page">
        <AppBar title={r.roomName || "방 입장 중"} back="/home" />
        <div className="page-body">
          <div className="empty">
            <span className="spinner" />
            <div className="empty__text">방에 들어가는 중...</div>
          </div>
        </div>
      </div>
    );
  }

  if (r.status === "playing") return <RoomGame r={r} />;
  if (r.status === "ended") return <RoomResult r={r} />;
  return <RoomLobby r={r} />;
}
