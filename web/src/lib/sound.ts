// The "정답" ding, played so that it MIXES with whatever the player is listening to.
//
// iOS Safari gives an <audio>/new Audio() element the "playback" audio session: the moment it
// plays, other apps' music (멜론, 스포티파이, 유튜브 뮤직 …) stops. Sound effects therefore go
// through Web Audio, and where Safari supports the Audio Session API the page also declares
// itself "ambient" — audio that mixes with other audio (and, like other ambient sounds, stays
// quiet when the phone is on silent).

type AudioSessionLike = { type: string };

let ctx: AudioContext | null = null;
let ding: AudioBuffer | null = null;
let loading: Promise<void> | null = null;

function declareAmbient(): void {
  try {
    const session = (navigator as Navigator & { audioSession?: AudioSessionLike }).audioSession;
    if (session && session.type !== "ambient") session.type = "ambient";
  } catch {
    /* not supported: Web Audio alone already avoids the media-playback session */
  }
}

function context(): AudioContext | null {
  if (ctx) return ctx;
  const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!AC) return null;
  try {
    ctx = new AC();
  } catch {
    ctx = null;
  }
  return ctx;
}

/**
 * Get ready to play. Browsers only start audio from a user gesture, so call this from one
 * (the first tap or key press is enough; see `primeOnFirstGesture`).
 */
export function primeSound(): void {
  declareAmbient();
  const c = context();
  if (!c) return;
  if (c.state === "suspended") void c.resume().catch(() => {});
  if (!ding && !loading) {
    loading = fetch("/sounds/ding.mp3")
      .then((r) => r.arrayBuffer())
      .then((data) => c.decodeAudioData(data))
      .then((buffer) => {
        ding = buffer;
      })
      .catch(() => {})
      .finally(() => {
        loading = null;
      });
  }
}

/** Prime on the first tap / key press anywhere on the page. Returns an unsubscribe. */
export function primeOnFirstGesture(): () => void {
  const once = () => {
    primeSound();
    off();
  };
  const off = () => {
    window.removeEventListener("pointerdown", once);
    window.removeEventListener("keydown", once);
  };
  window.addEventListener("pointerdown", once);
  window.addEventListener("keydown", once);
  return off;
}

export function playDing(volume = 0.4): void {
  const c = ctx;
  if (!c) return;
  if (!ding) {
    // first correct answer right after the first tap: the file is still decoding
    if (loading) void loading.then(() => ding && playDing(volume));
    return;
  }
  try {
    if (c.state === "suspended") void c.resume().catch(() => {});
    const src = c.createBufferSource();
    src.buffer = ding;
    const gain = c.createGain();
    gain.gain.value = volume;
    src.connect(gain).connect(c.destination);
    src.start();
  } catch {
    /* never let a sound effect break the game */
  }
}
