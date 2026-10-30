import { useAuth } from "../store/auth";

const BASE = "/api";

/** Error from the server. `.message` keeps the raw "401 Unauthorized: …" text; use
 * `friendlyError(e)` for a message that is fit to show a player. */
export class ApiError extends Error {
  status: number;
  detail: string | null;
  constructor(status: number, statusText: string, body: string) {
    super(`${status} ${statusText}: ${body}`);
    this.status = status;
    let detail: string | null = null;
    try {
      const j = JSON.parse(body);
      if (typeof j?.detail === "string") detail = j.detail;
    } catch {
      /* not JSON */
    }
    this.detail = detail;
  }
}

/** Korean, player-facing text for any error thrown by `api()` (like the app's ApiException). */
export function friendlyError(e: unknown): string {
  if (e instanceof ApiError) {
    if (e.status === 401) return "로그인이 만료됐어요. 다시 시도해 주세요";
    if (e.status === 404) return "찾을 수 없어요";
    if (e.status === 403) return "권한이 없어요";
    if (e.status === 422 || e.status === 400) return "입력 값을 확인해 주세요";
    if (e.status >= 500) return "서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요";
    return e.detail ?? "요청에 실패했어요";
  }
  if (e instanceof TypeError) return "서버에 연결할 수 없어요. 인터넷을 확인해 주세요";
  return e instanceof Error ? e.message : "알 수 없는 오류가 생겼어요";
}

function authHeaders(): HeadersInit {
  const t = localStorage.getItem("token");
  return t ? { Authorization: `Bearer ${t}` } : {};
}

// ── Silent re-login ─────────────────────────────────────────────────────────
// Guest tokens expire (7 days). The app answers a 401 by logging in again with the stored
// device id and retrying once; the web does the same. Concurrent 401s share one login.
let reloginInFlight: Promise<boolean> | null = null;

/** Log in again as the same guest (same device id, same nickname). Updates the auth store. */
export function reloginGuest(): Promise<boolean> {
  const { user, signIn } = useAuth.getState();
  if (!user) return Promise.resolve(false);
  if (!reloginInFlight) {
    reloginInFlight = (async () => {
      try {
        const r = await authApi.guestLogin(user.nickname);
        signIn(r.access_token, { user_id: r.user_id, nickname: r.nickname });
        return true;
      } catch {
        return false;
      } finally {
        reloginInFlight = null;
      }
    })();
  }
  return reloginInFlight;
}

export async function api<T>(
  path: string,
  init: RequestInit & { json?: unknown } = {},
  retried = false
): Promise<T> {
  const headers: HeadersInit = {
    "Content-Type": "application/json",
    ...authHeaders(),
    ...(init.headers ?? {}),
  };
  const body = init.json !== undefined ? JSON.stringify(init.json) : init.body;
  const res = await fetch(`${BASE}${path}`, { ...init, headers, body });

  const explicitAuth = init.headers && "Authorization" in (init.headers as Record<string, string>);
  if (res.status === 401 && !retried && !explicitAuth && !path.startsWith("/auth/")) {
    if (await reloginGuest()) return api<T>(path, init, true);
  }
  if (!res.ok) {
    throw new ApiError(res.status, res.statusText, await res.text());
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export interface TokenResponse {
  access_token: string;
  token_type: string;
  user_id: string;
  nickname: string;
}

export interface RoomListItem {
  id: string;
  code: string;
  name: string;
  is_public: boolean;
  player_count: number;
  max_players: number;
  status: string;
  win_score: number;
  created_at: string;
}

export interface RoomDetail extends RoomListItem {
  owner_id: string | null;
  round_seconds: number;
  categories: string[];
  difficulty_min: number;
  difficulty_max: number;
  question_set_id?: string | null;
}

// The server identifies a guest by a device id (same id -> same account) and hands out a
// "Guest_xxxx" nickname; the chosen nickname is applied afterwards via PATCH /auth/me.
const DEVICE_KEY = "device_id";

export function deviceId(): string {
  let id = localStorage.getItem(DEVICE_KEY);
  if (!id) {
    id =
      typeof crypto !== "undefined" && "randomUUID" in crypto
        ? crypto.randomUUID()
        : `web-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
    localStorage.setItem(DEVICE_KEY, id);
  }
  return id;
}

export const authApi = {
  guestLogin: async (nickname: string): Promise<TokenResponse> => {
    const login = await api<TokenResponse>("/auth/guest", {
      method: "POST",
      json: { device_id: deviceId() },
    });
    if (login.nickname === nickname) return login;
    // PATCH returns a fresh token that carries the new nickname (the WebSocket reads it).
    return api<TokenResponse>("/auth/me", {
      method: "PATCH",
      json: { nickname },
      headers: { Authorization: `Bearer ${login.access_token}` },
    });
  },
};

export const roomsApi = {
  list: () => api<RoomListItem[]>("/rooms"),
  create: (body: {
    name: string;
    is_public?: boolean;
    max_players?: number;
    win_score?: number;
    round_seconds?: number;
    categories?: string[];
    question_set_id?: string | null;
  }) => api<RoomDetail>("/rooms", { method: "POST", json: body }),
  get: (id: string) => api<RoomDetail>(`/rooms/${id}`),
  getByCode: (code: string) =>
    api<RoomDetail>(`/rooms/by-code/${encodeURIComponent(code.toUpperCase())}`),
};

// The room categories, which maps use too. Fetched once per page load.
let categoriesOnce: Promise<string[]> | null = null;

export const questionsApi = {
  categories: () => {
    if (!categoriesOnce) {
      categoriesOnce = api<string[]>("/questions/categories").catch((e) => {
        categoriesOnce = null; // retry on the next call
        throw e;
      });
    }
    return categoriesOnce;
  },
};
