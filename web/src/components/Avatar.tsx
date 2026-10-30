interface Props {
  name: string;
  size?: "sm" | "md" | "lg" | "xl";
  /** white-on-translucent variant for coloured backgrounds */
  onBrand?: boolean;
  crown?: boolean;
  /** show the online dot (true = green, false = grey, undefined = none) */
  online?: boolean;
}

/** First-letter avatar, like the app's UserAvatar. */
export function Avatar({ name, size = "md", onBrand, crown, online }: Props) {
  const cls = ["avatar", size !== "md" ? `avatar--${size}` : "", onBrand ? "avatar--onbrand" : ""].filter(Boolean).join(" ");
  const letters = Array.from(name.replace(/^[^\p{L}\p{N}]+/u, ""));
  const initial = letters.length ? letters[0].toUpperCase() : "?";
  return (
    <span className={cls} aria-hidden>
      {initial}
      {crown ? <span className="avatar__crown">👑</span> : null}
      {online !== undefined ? <span className={`avatar__dot ${online ? "is-on" : ""}`} /> : null}
    </span>
  );
}
