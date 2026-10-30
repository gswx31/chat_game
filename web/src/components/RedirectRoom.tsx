import { Navigate, useParams } from "react-router-dom";
import { roomPath } from "../lib/paths";

/** In-app links to the old `/rooms/:id` address land on the room page (see lib/paths.ts). */
export function RedirectRoom() {
  const { roomId = "" } = useParams();
  return <Navigate to={roomPath(roomId)} replace />;
}
