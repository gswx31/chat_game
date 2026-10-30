// "맵" = user-made question set. Mirrors mobile/lib/services/question_set_service.dart and
// backend/app/question_sets/{router,schemas}.py (server routes: /question-sets/...).
// Map themes and question categories are the room categories (questionsApi.categories).
import { api } from "./client";

/** Difficulty is 1~5 stars. The built-in bank uses 1~3; the 심화 maps add 4 and 5. */
export const DIFFICULTIES = [1, 2, 3, 4, 5] as const;
export const DIFFICULTY_LABELS: Record<number, string> = { 1: "★1", 2: "★2", 3: "★3", 4: "★4", 5: "★5" };
export const DIFFICULTY_NAMES: Record<number, string> = { 1: "쉬움", 2: "보통", 3: "어려움", 4: "심화", 5: "최고난도" };

/** The server rejects more than 10 alternative answers with 422. */
export const MAX_ACCEPTED_ANSWERS = 10;

export interface MapQuestion {
  id: string;
  set_id: string;
  prompt: string;
  answer: string;
  accepted_answers: string[];
  category: string;
  difficulty: number;
  hint: string | null;
  order: number;
}

export interface MapBrief {
  id: string;
  code: string;
  name: string;
  description: string | null;
  creator_id: string;
  creator_nickname: string;
  is_public: boolean;
  tags: string[];
  play_count: number;
  item_count: number;
  created_at: string;
  updated_at: string;
}

export interface MapDetail extends MapBrief {
  items: MapQuestion[];
}

/** Body for adding a question (also used for the `items` of a new map). */
export interface QuestionInput {
  prompt: string;
  answer: string;
  accepted_answers: string[];
  category: string;
  difficulty: number;
  hint?: string | null;
}

export interface MapInput {
  name: string;
  description?: string | null;
  is_public: boolean;
  tags: string[];
  items?: QuestionInput[];
}

export type BrowseSort = "popular" | "recent";

export interface BrowseParams {
  q?: string;
  tag?: string;
  sort?: BrowseSort;
  offset?: number;
  limit?: number;
}

/** The app only sends a hint when it is non-empty. */
function questionBody(q: Partial<QuestionInput>): Record<string, unknown> {
  const body: Record<string, unknown> = { ...q };
  if (!q.hint) delete body.hint;
  return body;
}

export const mapsApi = {
  listMine: () => api<MapBrief[]>("/question-sets/my"),

  get: (id: string) => api<MapDetail>(`/question-sets/${encodeURIComponent(id)}`),

  getByCode: (code: string) =>
    api<MapDetail>(`/question-sets/by-code/${encodeURIComponent(code.toUpperCase())}`),

  create: (input: MapInput) =>
    api<MapDetail>("/question-sets", {
      method: "POST",
      json: {
        name: input.name,
        ...(input.description ? { description: input.description } : {}),
        is_public: input.is_public,
        tags: input.tags,
        items: (input.items ?? []).map(questionBody),
      },
    }),

  update: (id: string, patch: Partial<Pick<MapInput, "name" | "description" | "is_public" | "tags">>) =>
    api<MapDetail>(`/question-sets/${encodeURIComponent(id)}`, { method: "PUT", json: patch }),

  remove: (id: string) =>
    api<void>(`/question-sets/${encodeURIComponent(id)}`, { method: "DELETE" }),

  addQuestion: (setId: string, q: QuestionInput) =>
    api<MapQuestion>(`/question-sets/${encodeURIComponent(setId)}/questions`, {
      method: "POST",
      json: questionBody(q),
    }),

  /** Unlike add, an explicit empty hint is sent so a hint can be cleared (the app does the same). */
  updateQuestion: (setId: string, questionId: string, q: Partial<QuestionInput>) =>
    api<MapQuestion>(
      `/question-sets/${encodeURIComponent(setId)}/questions/${encodeURIComponent(questionId)}`,
      { method: "PUT", json: q },
    ),

  removeQuestion: (setId: string, questionId: string) =>
    api<void>(
      `/question-sets/${encodeURIComponent(setId)}/questions/${encodeURIComponent(questionId)}`,
      { method: "DELETE" },
    ),

  /** Public maps, newest or most-played first. */
  browse: (p: BrowseParams = {}) => {
    const qs = new URLSearchParams({
      sort: p.sort ?? "popular",
      offset: String(p.offset ?? 0),
      limit: String(p.limit ?? 30),
    });
    if (p.q) qs.set("q", p.q);
    if (p.tag) qs.set("tag", p.tag);
    return api<MapBrief[]>(`/question-sets/browse?${qs.toString()}`);
  },

  /** "내 맵으로 가져오기": copies a public map into my maps. */
  clone: (id: string) =>
    api<MapDetail>(`/question-sets/${encodeURIComponent(id)}/clone`, { method: "POST", json: {} }),
};
