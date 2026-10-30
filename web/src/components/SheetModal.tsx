import { useEffect, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { useVisualViewport } from "../lib/useVisualViewport";

interface Props {
  title: string;
  subtitle?: string;
  onClose: () => void;
  children: ReactNode;
}

/**
 * Bottom sheet (the app's showModalBottomSheet): dims the page, closes on a tap outside or Esc,
 * and shrinks above the on-screen keyboard on phones.
 */
export function SheetModal({ title, subtitle, onClose, children }: Props) {
  useVisualViewport();

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [onClose]);

  return createPortal(
    <div className="backdrop backdrop--sheet sheet-backdrop" onClick={onClose}>
      <div className="sheet sheet--form" role="dialog" aria-modal="true" aria-label={title} onClick={(e) => e.stopPropagation()}>
        <div className="sheet__grip" />
        <div className="sheet-form__title">{title}</div>
        {subtitle ? <div className="sheet-form__sub">{subtitle}</div> : null}
        {children}
      </div>
    </div>,
    document.body,
  );
}
