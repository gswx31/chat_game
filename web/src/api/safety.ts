// Report / block other players. Mirrors backend/app/safety/router.py (Google Play's
// user-generated-content policy asks chat apps for both).
import { api } from "./client";

export type ReportReason = "abuse" | "sexual" | "spam" | "cheat" | "other";

export const REPORT_REASONS: { value: ReportReason; label: string; hint: string }[] = [
  { value: "abuse", label: "욕설·비하·괴롭힘", hint: "상대를 모욕하거나 괴롭히는 말" },
  { value: "sexual", label: "음란·선정적인 내용", hint: "닉네임이나 채팅에 포함된 경우" },
  { value: "spam", label: "도배·광고", hint: "같은 말을 반복하거나 홍보하는 경우" },
  { value: "cheat", label: "정답 유출·방해", hint: "정답을 퍼뜨리거나 게임을 망치는 행동" },
  { value: "other", label: "기타", hint: "아래에 내용을 적어 주세요" },
];

export interface ReportInput {
  target_user_id: string;
  reason: ReportReason;
  detail?: string;
  /** the chat line being reported, as the reporter saw it */
  message_text?: string;
  room_code?: string;
}

export interface BlockedUser {
  user_id: string;
  nickname: string;
  blocked_at: string; // ISO, UTC
}

export const safetyApi = {
  report: (body: ReportInput) => api<{ ok: boolean; duplicate: boolean }>("/safety/reports", { method: "POST", json: body }),
  blocks: () => api<BlockedUser[]>("/safety/blocks"),
  block: (userId: string) => api<{ ok: boolean }>(`/safety/blocks/${encodeURIComponent(userId)}`, { method: "PUT" }),
  unblock: (userId: string) => api<{ ok: boolean }>(`/safety/blocks/${encodeURIComponent(userId)}`, { method: "DELETE" }),
};
