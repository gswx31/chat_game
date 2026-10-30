import { create } from "zustand";

/** The build this page was loaded from (stamped by vite.config.ts). */
export const BUILD_ID: string = typeof __BUILD_ID__ === "string" ? __BUILD_ID__ : "dev";

const CHECK_EVERY_MS = 60_000;

interface UpdateState {
  /** A newer build than this page is being served. */
  updateAvailable: boolean;
  set: (v: boolean) => void;
}

export const useUpdate = create<UpdateState>((set) => ({ updateAvailable: false, set: (v) => set({ updateAvailable: v }) }));

/** Ask the server which build it serves now; flag when it is not ours. Never throws. */
export async function checkForUpdate(): Promise<void> {
  if (BUILD_ID === "dev") return;
  try {
    const res = await fetch(`/version.json?_=${Date.now()}`, { cache: "no-store" });
    if (!res.ok) return;
    const j = (await res.json()) as { build?: string };
    if (j.build && j.build !== BUILD_ID) useUpdate.getState().set(true);
  } catch {
    /* offline: try again later */
  }
}

/**
 * Keep an open tab from running stale code for hours after a deploy: check once a minute and
 * whenever the tab comes back into view. (A phone that was locked during a game comes back
 * through `visibilitychange`.)
 */
export function startUpdateWatch(): () => void {
  const onVisible = () => {
    if (document.visibilityState === "visible") void checkForUpdate();
  };
  void checkForUpdate();
  const timer = setInterval(() => void checkForUpdate(), CHECK_EVERY_MS);
  document.addEventListener("visibilitychange", onVisible);
  window.addEventListener("focus", onVisible);
  return () => {
    clearInterval(timer);
    document.removeEventListener("visibilitychange", onVisible);
    window.removeEventListener("focus", onVisible);
  };
}
