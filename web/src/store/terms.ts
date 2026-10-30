import { create } from "zustand";

/** Bump when the terms change in a way players must agree to again. */
export const TERMS_VERSION = "2026-10-24";
const KEY = "terms_accepted";

function read(): boolean {
  try {
    return localStorage.getItem(KEY) === TERMS_VERSION;
  } catch {
    return false;
  }
}

interface TermsState {
  accepted: boolean;
  accept: () => void;
}

/**
 * Whether this browser has agreed to the terms of use. Chat apps must have players accept the
 * rules before they can post (Google Play's user-generated-content policy), so every way into a
 * room asks for it once. Kept in the browser only: guests have no account to attach it to.
 */
export const useTerms = create<TermsState>((set) => ({
  accepted: read(),
  accept: () => {
    try {
      localStorage.setItem(KEY, TERMS_VERSION);
    } catch {
      /* private mode: asked again next visit */
    }
    set({ accepted: true });
  },
}));
