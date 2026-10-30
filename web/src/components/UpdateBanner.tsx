import { useEffect } from "react";
import { useLocation } from "react-router-dom";
import { startUpdateWatch, useUpdate } from "../lib/version";

/**
 * "새 버전이 나왔어요" strip. Inside a room the player decides when to reload (a reload drops the
 * chat log); on the home screen nothing is lost, so the page reloads itself there.
 */
export function UpdateBanner() {
  const available = useUpdate((s) => s.updateAvailable);
  const { pathname } = useLocation();

  useEffect(() => startUpdateWatch(), []);

  useEffect(() => {
    if (available && pathname === "/home") window.location.reload();
  }, [available, pathname]);

  if (!available) return null;
  return (
    <div className="update-banner" role="status">
      <span>새 버전이 나왔어요</span>
      <button className="update-banner__btn" onClick={() => window.location.reload()}>
        새로고침
      </button>
    </div>
  );
}
