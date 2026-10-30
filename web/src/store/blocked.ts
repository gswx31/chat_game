import { create } from "zustand";
import { safetyApi } from "../api/safety";

interface BlockedState {
  /**
   * Blocked user id -> when this screen learned of the block (ms). The server withholds a
   * blocked player's chat from then on; lines of theirs that reached the screen earlier are
   * hidden by comparing their receive time with this one. (A line that arrives later was let
   * through by the server, e.g. because the block was lifted in another tab, so it is shown.)
   */
  at: Record<string, number>;
  load: () => Promise<void>;
  block: (userId: string) => Promise<void>;
  unblock: (userId: string) => Promise<void>;
}

export const useBlocked = create<BlockedState>((set, get) => ({
  at: {},
  load: async () => {
    try {
      const list = await safetyApi.blocks();
      const now = Date.now();
      const prev = get().at;
      const next: Record<string, number> = {};
      for (const b of list) next[b.user_id] = prev[b.user_id] ?? now;
      set({ at: next });
    } catch {
      /* offline: keep what we have */
    }
  },
  block: async (userId) => {
    await safetyApi.block(userId);
    set((s) => ({ at: { ...s.at, [userId]: Date.now() } }));
  },
  unblock: async (userId) => {
    await safetyApi.unblock(userId);
    set((s) => {
      const { [userId]: _gone, ...rest } = s.at;
      return { at: rest };
    });
  },
}));

/** Should a chat line from `userId` that was received at `ts` be hidden? */
export function isHidden(at: Record<string, number>, userId: string | undefined, ts: number): boolean {
  return !!userId && userId in at && ts <= at[userId];
}
