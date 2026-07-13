const BASE = "/api";

function authHeaders(): HeadersInit {
  const t = localStorage.getItem("token");
  return t ? { Authorization: `Bearer ${t}` } : {};
}

export async function api<T>(
  path: string,
  init: RequestInit & { json?: unknown } = {}
): Promise<T> {
  const headers: HeadersInit = {
    "Content-Type": "application/json",
    ...authHeaders(),
    ...(init.headers ?? {}),
  };
  const body = init.json !== undefined ? JSON.stringify(init.json) : init.body;
  const res = await fetch(`${BASE}${path}`, { ...init, headers, body });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${res.status} ${res.statusText}: ${text}`);
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
}

export const authApi = {
  guestLogin: (nickname: string) =>
    api<TokenResponse>("/auth/guest", { method: "POST", json: { nickname } }),
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
  }) => api<RoomDetail>("/rooms", { method: "POST", json: body }),
  get: (id: string) => api<RoomDetail>(`/rooms/${id}`),
  getByCode: (code: string) =>
    api<RoomDetail>(`/rooms/by-code/${encodeURIComponent(code.toUpperCase())}`),
};

export const questionsApi = {
  categories: () => api<string[]>("/questions/categories"),
};
