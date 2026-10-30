/**
 * The 상식퀴즈배틀 mascot (a speech bubble with a face and a lightning bolt: answers typed into
 * chat, first one wins) and the two-tone outlined wordmark. Both are inline SVG so they stay
 * sharp at any size and need no image request.
 */

const INK = "#3b2667";

export function Mascot({ size = 140, className }: { size?: number; className?: string }) {
  return (
    <svg className={className} width={size} height={size} viewBox="0 0 200 200" role="img" aria-label="상식퀴즈배틀 마스코트">
      {/* little thought bubbles */}
      <circle cx="30" cy="34" r="10" fill="#cdb8f2" />
      <circle cx="14" cy="58" r="6" fill="#cdb8f2" />
      <circle cx="170" cy="170" r="9" fill="#cdb8f2" />
      {/* the bubble */}
      <path
        d="M100 30c-41 0-72 26-72 62 0 21 11 39 28 50l-9 27c-1 4 3 7 6 5l30-17c5 1 11 1 17 1 41 0 72-26 72-62s-31-66-72-66z"
        fill="#d9c9f7"
        stroke={INK}
        strokeWidth="8"
        strokeLinejoin="round"
      />
      {/* face */}
      <ellipse cx="78" cy="88" rx="7" ry="9" fill={INK} />
      <ellipse cx="122" cy="88" rx="7" ry="9" fill={INK} />
      <circle cx="80" cy="85" r="2.4" fill="#fff" />
      <circle cx="124" cy="85" r="2.4" fill="#fff" />
      <path d="M84 108c9 9 23 9 32 0" fill="none" stroke={INK} strokeWidth="6" strokeLinecap="round" />
      <ellipse cx="64" cy="106" rx="8" ry="5" fill="#f6a5c0" opacity="0.8" />
      <ellipse cx="136" cy="106" rx="8" ry="5" fill="#f6a5c0" opacity="0.8" />
      {/* the battle bolt, on the bubble's shoulder */}
      <path d="M174 24l-26 42h18l-11 34 36-48h-19l12-28z" fill="#ffd257" stroke={INK} strokeWidth="6" strokeLinejoin="round" />
    </svg>
  );
}

/** "상식퀴즈배틀" in a chunky rounded face: yellow + lavender with a thick dark outline. */
export function Wordmark({ height = 44, className }: { height?: number; className?: string }) {
  const style = { fontFamily: "Jua, 'Black Han Sans', 'Apple SD Gothic Neo', sans-serif" };
  return (
    <svg className={className} height={height} viewBox="0 0 330 64" role="img" aria-label="상식퀴즈배틀">
      <text x="165" y="50" fontSize="52" textAnchor="middle" style={style} stroke={INK} strokeWidth="9" strokeLinejoin="round" paintOrder="stroke">
        <tspan fill="#ffd257">상식퀴즈</tspan>
        <tspan fill="#cdb8f2">배틀</tspan>
      </text>
    </svg>
  );
}

/** Mascot over wordmark, the block at the top of the start and home screens. */
export function BrandBlock({ mascot = 132, word = 46 }: { mascot?: number; word?: number }) {
  return (
    <div className="brand">
      <Mascot size={mascot} className="brand__mascot" />
      <Wordmark height={word} className="brand__word" />
    </div>
  );
}
