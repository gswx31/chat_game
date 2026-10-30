import { useEffect, useState, type ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { Icon } from "./icons";

interface Props {
  title: string;
  /** Show the ← button. `true` = history back (falls back to /home), string = go there. */
  back?: boolean | string;
  /** Right-hand buttons (use <button className="icon-btn"> or "appbar__text-btn"). */
  actions?: ReactNode;
  /** Kept for the callers; every variant now renders the same light bar. */
  variant?: "indigo" | "primary" | "gradient" | "dark";
  onBack?: () => void;
}

/** Light app bar: round lavender back button, the title in deep purple. */
export function AppBar({ title, back = true, actions, variant = "indigo", onBack }: Props) {
  const nav = useNavigate();
  function goBack() {
    if (onBack) return onBack();
    if (typeof back === "string") return nav(back);
    if (window.history.length > 1) nav(-1);
    else nav("/home");
  }
  // Transparent over the page's decorative circles; it only gets a backdrop once content
  // scrolls underneath it.
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 4);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);
  const cls = (variant === "indigo" ? "" : ` appbar--${variant}`) + (scrolled ? " is-scrolled" : "");
  return (
    <header className={`appbar${cls}`}>
      <div className="appbar__side">
        {back ? (
          <button className="icon-btn" aria-label="뒤로" onClick={goBack}>
            <Icon name="back" size={22} />
          </button>
        ) : null}
      </div>
      <div className="appbar__title">{title}</div>
      <div className="appbar__side appbar__side--end">{actions}</div>
    </header>
  );
}
