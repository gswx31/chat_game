import { useEffect } from "react";

/**
 * Keeps the CSS variable `--vvh` equal to the height that is really visible. On iPhone Safari
 * the on-screen keyboard does not shrink `100dvh`, so a bottom-pinned chat input would hide
 * behind it; with `--vvh` the page shrinks above the keyboard like the app's
 * `resizeToAvoidBottomInset`.
 */
export function useVisualViewport(): void {
  useEffect(() => {
    const vv = window.visualViewport;
    const root = document.documentElement;
    const apply = () => {
      const h = vv ? vv.height : window.innerHeight;
      root.style.setProperty("--vvh", `${Math.round(h)}px`);
      // keyboard up (the visible area is much shorter than the window): let the CSS compact the screen
      root.classList.toggle("kb-open", window.innerHeight - h > 120);
      // iOS scrolls the page when the keyboard opens; keep the frame pinned to the top
      if (vv && vv.offsetTop > 0) window.scrollTo(0, 0);
    };
    apply();
    vv?.addEventListener("resize", apply);
    vv?.addEventListener("scroll", apply);
    window.addEventListener("resize", apply);
    return () => {
      vv?.removeEventListener("resize", apply);
      vv?.removeEventListener("scroll", apply);
      window.removeEventListener("resize", apply);
      root.style.removeProperty("--vvh");
      root.classList.remove("kb-open");
    };
  }, []);
}
