import { create } from "zustand";

// Per-device settings (localStorage). The app keeps nothing like this, the web only has the
// sound switch so far; `soundEnabled()` is for non-React code (e.g. the room's ding).
const KEY = "prefs";

interface Prefs {
  sound: boolean;
}

function load(): Prefs {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const j = JSON.parse(raw) as Partial<Prefs>;
      return { sound: j.sound !== false };
    }
  } catch {
    /* storage blocked or corrupt: fall back to defaults */
  }
  return { sound: true };
}

function save(p: Prefs) {
  try {
    localStorage.setItem(KEY, JSON.stringify(p));
  } catch {
    /* private mode: the choice just lasts until the page is closed */
  }
}

interface PrefsState extends Prefs {
  setSound: (on: boolean) => void;
}

export const usePrefs = create<PrefsState>((set, get) => ({
  ...load(),
  setSound: (sound) => {
    set({ sound });
    save({ sound: get().sound });
  },
}));

export const soundEnabled = (): boolean => usePrefs.getState().sound;
