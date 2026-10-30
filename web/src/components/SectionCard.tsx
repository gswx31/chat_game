import type { ReactNode } from "react";

interface Props {
  icon: string;
  /** icon-box colour modifier: primary | accent | blue | red | orange | purple | ghost */
  color?: string;
  title: string;
  subtitle?: string;
  badge?: ReactNode;
  children?: ReactNode;
}

/** White card with a coloured icon box + title (the app's create-room `_FormSection`). */
export function SectionCard({ icon, color = "primary", title, subtitle, badge, children }: Props) {
  return (
    <section className="card">
      <div className="section-head" style={children ? undefined : { marginBottom: 0 }}>
        <span className={`icon-box icon-box--${color}`}>{icon}</span>
        <div className="section-head__text">
          <div className="section-head__title">{title}</div>
          {subtitle ? <div className="section-head__sub">{subtitle}</div> : null}
        </div>
        {badge}
      </div>
      {children}
    </section>
  );
}
