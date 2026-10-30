import { useState, type FormEvent } from "react";
import { friendlyError } from "../../api/client";
import { DIFFICULTIES, DIFFICULTY_LABELS, DIFFICULTY_NAMES, MAX_ACCEPTED_ANSWERS, type MapQuestion } from "../../api/maps";
import { toast } from "../../components/feedback";
import { Glyph } from "../../components/Glyph";
import { SheetModal } from "../../components/SheetModal";
import "../../styles/maps.css";

/** A question while it is being edited; `id` is missing until the server has stored it. */
export interface LocalQuestion {
  id?: string;
  prompt: string;
  answer: string;
  accepted_answers: string[];
  category: string;
  difficulty: number;
  hint: string | null;
}

export function fromServer(q: MapQuestion): LocalQuestion {
  return {
    id: q.id,
    prompt: q.prompt,
    answer: q.answer,
    accepted_answers: q.accepted_answers,
    category: q.category,
    difficulty: q.difficulty,
    hint: q.hint,
  };
}

interface Props {
  existing?: LocalQuestion;
  /** The room categories (questionsApi.categories). */
  categories: string[];
  /** Throw to keep the sheet open (the message is shown as a toast). */
  onSave: (q: LocalQuestion) => Promise<void>;
  onClose: () => void;
}

/** 문제 추가 / 편집 bottom sheet (_QuestionDialog in question_set_edit_screen.dart). */
export function QuestionSheet({ existing, categories, onSave, onClose }: Props) {
  const [prompt, setPrompt] = useState(existing?.prompt ?? "");
  const [answer, setAnswer] = useState(existing?.answer ?? "");
  const [extra, setExtra] = useState(existing?.accepted_answers.join(", ") ?? "");
  const [category, setCategory] = useState(existing?.category ?? categories[0]);
  const [difficulty, setDifficulty] = useState(existing?.difficulty ?? 2);
  const [hint, setHint] = useState(existing?.hint ?? "");
  const [saving, setSaving] = useState(false);
  const [promptError, setPromptError] = useState<string | null>(null);
  const [answerError, setAnswerError] = useState<string | null>(null);
  const [extraError, setExtraError] = useState<string | null>(null);

  // a map loaded from the server may use a category that is not in the list (older maps)
  const choices = categories.includes(category) ? categories : [category, ...categories];

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (saving) return;
    const p = prompt.trim();
    const a = answer.trim();
    setPromptError(p ? null : "문제 내용을 입력해주세요.");
    setAnswerError(a ? null : "정답을 입력해주세요.");
    if (!p || !a) return;

    const accepted = extra
      .split(/[,，]/)
      .map((s) => s.trim())
      .filter(Boolean);
    // the server answers 422 for more than 10 extra answers
    if (accepted.length > MAX_ACCEPTED_ANSWERS) {
      setExtraError(`추가 정답은 ${MAX_ACCEPTED_ANSWERS}개까지만 넣을 수 있어요.`);
      return;
    }

    setSaving(true);
    try {
      await onSave({
        id: existing?.id,
        prompt: p,
        answer: a,
        accepted_answers: accepted,
        category,
        difficulty,
        hint: hint.trim() || null,
      });
      onClose();
    } catch (err) {
      toast(`저장 실패: ${friendlyError(err)}`, "error");
      setSaving(false);
    }
  }

  return (
    <SheetModal title={existing ? "문제 편집" : "문제 추가"} onClose={onClose}>
      <form onSubmit={submit} noValidate>
        <div className="field">
          <label className="field__label" htmlFor="q-prompt">문제 내용 *</label>
          <textarea
            id="q-prompt"
            className={`input input--area ${promptError ? "input--error" : ""}`}
            value={prompt}
            maxLength={500}
            rows={3}
            placeholder="예: 대한민국의 수도는?"
            onChange={(e) => {
              setPrompt(e.target.value);
              setPromptError(null);
            }}
          />
          {promptError ? <span className="field-error">{promptError}</span> : <span className="field__count">{prompt.length}/500</span>}
        </div>

        <div className="field">
          <label className="field__label" htmlFor="q-answer">정답 *</label>
          <div className="input-icon">
            <span className="input-icon__glyph" style={{ color: "var(--accent)" }}>
              <Glyph name="checkCircle" size={20} />
            </span>
            <input
              id="q-answer"
              className={`input ${answerError ? "input--error" : ""}`}
              value={answer}
              maxLength={120}
              autoComplete="off"
              onChange={(e) => {
                setAnswer(e.target.value);
                setAnswerError(null);
              }}
            />
          </div>
          {answerError ? <span className="field-error">{answerError}</span> : null}
        </div>

        <div className="field">
          <label className="field__label" htmlFor="q-extra">추가 정답 <small>(쉼표로 구분, 선택)</small></label>
          <input
            id="q-extra"
            className={`input ${extraError ? "input--error" : ""}`}
            value={extra}
            autoComplete="off"
            placeholder="예: H₂O, 에이치투오"
            onChange={(e) => {
              setExtra(e.target.value);
              setExtraError(null);
            }}
          />
          {extraError ? <span className="field-error">{extraError}</span> : null}
        </div>

        <div className="field">
          <label className="field__label" htmlFor="q-category">카테고리</label>
          <select id="q-category" className="select" value={category} onChange={(e) => setCategory(e.target.value)}>
            {choices.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </div>

        <div className="field">
          <span className="field__label">난이도</span>
          <div className="diff-seg" role="radiogroup" aria-label="난이도">
            {DIFFICULTIES.map((d) => (
              <button
                key={d}
                type="button"
                role="radio"
                aria-checked={difficulty === d}
                aria-label={`별 ${d}개 (${DIFFICULTY_NAMES[d]})`}
                className={`diff-seg__btn diff-seg__btn--d${d} ${difficulty === d ? "is-on" : ""}`}
                onClick={() => setDifficulty(d)}
              >
                {DIFFICULTY_LABELS[d]}
              </button>
            ))}
          </div>
          <div className="diff-seg__hint">{DIFFICULTY_NAMES[difficulty] ?? ""}</div>
        </div>

        <div className="field">
          <label className="field__label" htmlFor="q-hint">
            <span style={{ display: "inline-flex", alignItems: "center", gap: 5 }}>
              <Glyph name="lightbulb" size={15} color="var(--warning)" />
              힌트 <small>(선택 — 없으면 초성 자동 생성)</small>
            </span>
          </label>
          <input id="q-hint" className="input" value={hint} maxLength={120} autoComplete="off" onChange={(e) => setHint(e.target.value)} />
        </div>

        <button className="btn btn--block" type="submit" disabled={saving}>
          {saving ? <span className="spinner spinner--white" role="status" aria-label="저장 중" /> : existing ? "저장하기" : "추가하기"}
        </button>
      </form>
    </SheetModal>
  );
}
