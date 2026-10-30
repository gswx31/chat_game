import { useCallback } from "react";
import { useNavigate } from "react-router-dom";

/** Same rule as AppBar's built-in ←: browser history back, or `fallback` for a fresh tab. */
export function useGoBack(fallback = "/home"): () => void {
  const nav = useNavigate();
  return useCallback(() => {
    if (window.history.length > 1) nav(-1);
    else nav(fallback, { replace: true });
  }, [nav, fallback]);
}
