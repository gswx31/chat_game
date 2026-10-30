import type { ReactNode } from "react";
import { Glyph, type GlyphName } from "./Glyph";

/** Centered spinner while a screen loads. */
export function LoadingView() {
  return <div className="spinner" role="status" aria-label="불러오는 중" />;
}

/** "불러오기 실패" + 다시 시도, like the app's _ErrorView. */
export function ErrorView({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="empty" role="alert">
      <div className="empty__icon" style={{ background: "rgba(239,68,68,0.1)", color: "var(--danger)" }}>
        <Glyph name="error" size={44} />
      </div>
      <div className="empty__title">불러오기 실패</div>
      <div style={{ fontSize: 13, marginBottom: 18 }}>{message}</div>
      {onRetry ? (
        <button className="btn btn--sm" onClick={onRetry}>
          다시 시도
        </button>
      ) : null}
    </div>
  );
}

/** Round tinted icon + title + helper text. */
export function EmptyView({ icon, title, children }: { icon: GlyphName; title: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <div className="empty__icon" style={{ color: "var(--primary)" }}>
        <Glyph name={icon} size={44} />
      </div>
      <div className="empty__title">{title}</div>
      {children ? <div style={{ fontSize: 14, lineHeight: 1.5 }}>{children}</div> : null}
    </div>
  );
}
