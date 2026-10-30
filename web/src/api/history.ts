// "내 전적". Mirrors mobile/lib/models/game_history.dart and GET /history/me.
import { api } from "./client";

export interface HistoryItem {
  id: number;
  played_at: string; // ISO, UTC
  room_name: string;
  score: number;
  rank: number;
  player_count: number;
  win_score: number;
  winner_nickname: string | null;
  won: boolean;
}

export interface HistorySummary {
  games: number;
  wins: number;
  total_score: number;
  items: HistoryItem[];
}

/** The server's maximum page size; the app also asks for the latest 100. */
export const HISTORY_PAGE_SIZE = 100;

export const historyApi = {
  mine: () => api<HistorySummary>(`/history/me?limit=${HISTORY_PAGE_SIZE}`),
};

/** 1-3 get medals, the rest "N등" (same as the app). */
export function rankLabel(rank: number): string {
  switch (rank) {
    case 1: return "🥇";
    case 2: return "🥈";
    case 3: return "🥉";
    default: return `${rank}등`;
  }
}

/** "10월 23일 오후 1:05" in the device's time zone (no locale setup needed; same as the app). */
export function formatPlayedAt(iso: string): string {
  const t = new Date(iso);
  const period = t.getHours() < 12 ? "오전" : "오후";
  const hour12 = t.getHours() % 12 === 0 ? 12 : t.getHours() % 12;
  const minute = String(t.getMinutes()).padStart(2, "0");
  return `${t.getMonth() + 1}월 ${t.getDate()}일 ${period} ${hour12}:${minute}`;
}
