import { useEffect } from "react";
import { create } from "zustand";

// ── Toast (like the app's SnackBar) ─────────────────────────────────────────
type ToastKind = "info" | "ok" | "error";
interface ToastItem {
  id: number;
  text: string;
  kind: ToastKind;
}
interface ToastState {
  items: ToastItem[];
  push: (text: string, kind: ToastKind) => void;
  drop: (id: number) => void;
}

let seq = 0;
const useToastStore = create<ToastState>((set) => ({
  items: [],
  push: (text, kind) => {
    const id = ++seq;
    set((s) => ({ items: [...s.items.slice(-2), { id, text, kind }] }));
    setTimeout(() => set((s) => ({ items: s.items.filter((t) => t.id !== id) })), 2600);
  },
  drop: (id) => set((s) => ({ items: s.items.filter((t) => t.id !== id) })),
}));

/** toast("링크를 복사했어요", "ok") */
export function toast(text: string, kind: ToastKind = "info") {
  useToastStore.getState().push(text, kind);
}

export function ToastHost() {
  const items = useToastStore((s) => s.items);
  return (
    <div className="toast-host" aria-live="polite">
      {items.map((t) => (
        <div key={t.id} className={`toast ${t.kind === "info" ? "" : `toast--${t.kind}`}`}>
          {t.text}
        </div>
      ))}
    </div>
  );
}

// ── Confirm dialog (like ConfirmDialog.show) ────────────────────────────────
interface ConfirmOptions {
  title: string;
  content: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
}
interface DialogState {
  open: (ConfirmOptions & { resolve: (ok: boolean) => void }) | null;
  set: (v: DialogState["open"]) => void;
}
const useDialogStore = create<DialogState>((set) => ({ open: null, set: (open) => set({ open }) }));

/** `if (await confirmDialog({ title: "강퇴", content: "…" })) …` */
export function confirmDialog(opts: ConfirmOptions): Promise<boolean> {
  return new Promise((resolve) => useDialogStore.getState().set({ ...opts, resolve }));
}

export function DialogHost() {
  const open = useDialogStore((s) => s.open);
  const set = useDialogStore((s) => s.set);
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") finish(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);
  if (!open) return null;
  function finish(ok: boolean) {
    open!.resolve(ok);
    set(null);
  }
  return (
    <div className="backdrop" onClick={() => finish(false)}>
      <div className="dialog" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}>
        <div className="dialog__title">{open.title}</div>
        <div className="dialog__body">{open.content}</div>
        <div className="dialog__actions">
          <button className="btn btn--ghost btn--sm" onClick={() => finish(false)}>
            {open.cancelLabel ?? "취소"}
          </button>
          <button className={`btn btn--sm ${open.danger === false ? "" : "btn--danger"}`} onClick={() => finish(true)}>
            {open.confirmLabel ?? "확인"}
          </button>
        </div>
      </div>
    </div>
  );
}
