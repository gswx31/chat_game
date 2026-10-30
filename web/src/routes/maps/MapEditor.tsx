import { useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { friendlyError, questionsApi } from "../../api/client";
import { DIFFICULTY_LABELS, mapsApi, type QuestionInput } from "../../api/maps";
import { AppBar } from "../../components/AppBar";
import { confirmDialog, toast } from "../../components/feedback";
import { Glyph } from "../../components/Glyph";
import { RequireUser } from "../../components/RequireUser";
import { ErrorView, LoadingView } from "../../components/StateViews";
import { useGoBack } from "../../lib/nav";
import { copyText } from "../../lib/share";
import { useLoad } from "../../lib/useLoad";
import "../../styles/maps.css";
import { fromServer, QuestionSheet, type LocalQuestion } from "./QuestionSheet";
import { mapPaths } from "./paths";

/** 새 맵 만들기 / 맵 편집 (mobile/lib/screens/question_sets/question_set_edit_screen.dart). */
export default function MapEditor() {
  return (
    <RequireUser>
      <MapEditorView />
    </RequireUser>
  );
}

function toInput(q: LocalQuestion): QuestionInput {
  return {
    prompt: q.prompt,
    answer: q.answer,
    accepted_answers: q.accepted_answers,
    category: q.category,
    difficulty: q.difficulty,
    hint: q.hint,
  };
}

function MapEditorView() {
  const { id: idParam } = useParams();
  const setId = idParam && idParam !== "new" ? idParam : null;
  const isCreate = setId === null;
  const nav = useNavigate();
  const goBack = useGoBack(mapPaths.list);

  // existing map: fetch once, then the form below owns the values
  const { data, error, reload } = useLoad(() => (setId ? mapsApi.get(setId) : Promise.resolve(null)), setId ?? "new");
  // themes and question categories = the categories offered when creating a room
  const cats = useLoad(() => questionsApi.categories());

  const [name, setName] = useState("");
  const [desc, setDesc] = useState("");
  const [isPublic, setIsPublic] = useState(true);
  const [tags, setTags] = useState<string[]>([]);
  const [questions, setQuestions] = useState<LocalQuestion[]>([]);
  const [shareCode, setShareCode] = useState<string | null>(null);
  const [savedPublic, setSavedPublic] = useState(true);
  const [nameError, setNameError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [sheet, setSheet] = useState<{ existing?: LocalQuestion; index?: number } | null>(null);
  const base = useRef({ name: "", desc: "", isPublic: true, tags: "" });

  useEffect(() => {
    if (!data) return;
    setName(data.name);
    setDesc(data.description ?? "");
    setIsPublic(data.is_public);
    setSavedPublic(data.is_public);
    setTags(data.tags);
    setShareCode(data.code);
    setQuestions(data.items.map(fromServer));
    base.current = { name: data.name, desc: data.description ?? "", isPublic: data.is_public, tags: [...data.tags].sort().join("|") };
  }, [data]);

  const dirty = isCreate
    ? name.trim() !== "" || desc.trim() !== "" || tags.length > 0 || questions.length > 0
    : name !== base.current.name || desc !== base.current.desc || isPublic !== base.current.isPublic || [...tags].sort().join("|") !== base.current.tags;

  async function leave() {
    if (dirty) {
      const ok = await confirmDialog({
        title: "변경 취소",
        content: isCreate ? "만들던 맵이 사라져요. 나가시겠습니까?" : "저장하지 않은 변경 사항이 있습니다. 나가시겠습니까?",
        confirmLabel: "나가기",
        cancelLabel: "계속 편집",
        danger: false,
      });
      if (!ok) return;
    }
    goBack();
  }

  async function save() {
    if (saving) return;
    const n = name.trim();
    setNameError(n ? null : "맵 이름을 입력해주세요.");
    if (!n) return;
    if (questions.length === 0) {
      toast("문제를 최소 1개 이상 추가해주세요.", "error");
      return;
    }
    setSaving(true);
    try {
      if (isCreate) {
        await mapsApi.create({
          name: n,
          description: desc.trim() || null,
          is_public: isPublic,
          tags,
          items: questions.map(toInput),
        });
        toast("맵이 생성되었습니다!", "ok");
      } else {
        // "" (not null) so that a description can be cleared
        await mapsApi.update(setId, { name: n, description: desc.trim(), is_public: isPublic, tags });
        toast("저장되었습니다.", "ok");
      }
      nav(mapPaths.list, { replace: true });
    } catch (e) {
      setSaving(false);
      toast(`저장 실패: ${friendlyError(e)}`, "error");
    }
  }

  async function saveQuestion(q: LocalQuestion) {
    const index = sheet?.index;
    if (isCreate) {
      setQuestions((list) => (index !== undefined ? list.map((x, i) => (i === index ? q : x)) : [...list, q]));
      return;
    }
    if (q.id && index !== undefined) {
      // an explicit "" clears the hint on the server
      const saved = await mapsApi.updateQuestion(setId, q.id, { ...toInput(q), hint: q.hint ?? "" });
      setQuestions((list) => list.map((x, i) => (i === index ? fromServer(saved) : x)));
    } else {
      const saved = await mapsApi.addQuestion(setId, toInput(q));
      setQuestions((list) => [...list, fromServer(saved)]);
    }
  }

  async function deleteQuestion(index: number) {
    const q = questions[index];
    const ok = await confirmDialog({ title: "문제 삭제", content: "이 문제를 삭제할까요?", confirmLabel: "삭제" });
    if (!ok) return;
    if (!isCreate && q.id) {
      try {
        await mapsApi.removeQuestion(setId, q.id);
      } catch (e) {
        toast(`삭제 실패: ${friendlyError(e)}`, "error");
        return;
      }
    }
    setQuestions((list) => list.filter((_, i) => i !== index));
  }

  function toggleTag(t: string) {
    setTags((cur) => (cur.includes(t) ? cur.filter((x) => x !== t) : [...cur, t]));
  }

  const title = isCreate ? "새 맵 만들기" : "맵 편집";

  if ((!isCreate && !data) || !cats.data) {
    const failed = error ?? cats.error;
    const retry = () => {
      if (error) reload();
      if (cats.error) cats.reload();
    };
    return (
      <div className="app-page">
        <AppBar title={title} back={mapPaths.list} />
        <div className="page-body">{failed ? <ErrorView message={failed} onRetry={retry} /> : <LoadingView />}</div>
      </div>
    );
  }
  const categories = cats.data;
  // a tag the list no longer has (older maps) stays visible so it can be switched off
  const themes = [...categories, ...tags.filter((t) => !categories.includes(t))];

  return (
    <div className="app-page">
      <AppBar
        title={title}
        onBack={leave}
        actions={
          saving ? (
            <span className="appbar__busy">
              <span className="spinner spinner--white" role="status" aria-label="저장 중" />
            </span>
          ) : (
            <button className="appbar__text-btn" onClick={save}>
              저장
            </button>
          )
        }
      />
      <div className="page-body">
        {!isCreate && shareCode ? <ShareCodeCard code={shareCode} name={name} isPublic={savedPublic} /> : null}

        <div className="field">
          <label className="map-label" htmlFor="m-name">맵 이름</label>
          <div className="input-icon">
            <span className="input-icon__glyph">
              <Glyph name="map" size={20} />
            </span>
            <input
              id="m-name"
              className={`input ${nameError ? "input--error" : ""}`}
              value={name}
              maxLength={80}
              placeholder="예: 한국사 완전정복"
              autoComplete="off"
              onChange={(e) => {
                setName(e.target.value);
                setNameError(null);
              }}
            />
          </div>
          {nameError ? <span className="field-error">{nameError}</span> : <span className="field__count">{name.length}/80</span>}
        </div>

        <div className="field">
          <label className="map-label" htmlFor="m-desc">설명 (선택)</label>
          <textarea
            id="m-desc"
            className="input input--area"
            value={desc}
            maxLength={300}
            rows={2}
            placeholder="이 맵에 대한 간단한 설명"
            onChange={(e) => setDesc(e.target.value)}
          />
          <span className="field__count">{desc.length}/300</span>
        </div>

        <div>
          <div className="map-label">테마</div>
          <div className="map-hint">해당되는 테마를 모두 선택하세요</div>
          <div className="chip-row" style={{ marginTop: 10 }}>
            {themes.map((t) => (
              <button key={t} type="button" className={`chip chip--soft ${tags.includes(t) ? "is-on" : ""}`} aria-pressed={tags.includes(t)} onClick={() => toggleTag(t)}>
                {tags.includes(t) ? <Glyph name="check" size={16} /> : null}
                {t}
              </button>
            ))}
          </div>
        </div>

        <label className="map-switch-row">
          <span className="map-switch-row__body">
            <span className="map-switch-row__title" style={{ display: "block" }}>공개 맵</span>
            <span className="map-switch-row__sub" style={{ display: "block" }}>다른 사용자도 이 맵을 검색하고 사용할 수 있습니다</span>
          </span>
          <span className="switch">
            <input type="checkbox" role="switch" checked={isPublic} onChange={(e) => setIsPublic(e.target.checked)} aria-label="공개 맵" />
            <span className="switch__track" />
          </span>
        </label>

        <div className="map-list-head">
          <span className="map-label">문제 목록</span>
          <span className="count-pill">{questions.length}문제</span>
        </div>

        {questions.length === 0 ? (
          <div className="map-empty-box">
            <Glyph name="list" size={44} color="var(--text-2)" />
            아직 문제가 없어요
            <br />
            아래 버튼으로 문제를 추가해보세요!
          </div>
        ) : (
          <div className="list" style={{ gap: 10 }}>
            {questions.map((q, i) => (
              <QuestionCard key={q.id ?? `new-${i}`} q={q} index={i} onEdit={() => setSheet({ existing: q, index: i })} onDelete={() => deleteQuestion(i)} />
            ))}
          </div>
        )}
      </div>

      <div className="map-fab-dock">
        <button className="map-fab" onClick={() => setSheet({})}>
          <Glyph name="add" size={22} />문제 추가
        </button>
      </div>

      {sheet ? <QuestionSheet existing={sheet.existing} categories={categories} onSave={saveQuestion} onClose={() => setSheet(null)} /> : null}
    </div>
  );
}

function QuestionCard({ q, index, onEdit, onDelete }: { q: LocalQuestion; index: number; onEdit: () => void; onDelete: () => void }) {
  const d = q.difficulty >= 1 && q.difficulty <= 5 ? q.difficulty : 2;
  return (
    <div className="map-q">
      <div className="map-q__no">{index + 1}</div>
      <div className="map-q__body">
        <div className="map-q__prompt">{q.prompt}</div>
        <div className="map-q__meta">
          <span className="mini-badge mini-badge--primary">{q.category}</span>
          <span className={`mini-badge mini-badge--d${d}`}>{DIFFICULTY_LABELS[d]}</span>
          <span className="map-q__answer">정답: {q.answer}</span>
        </div>
      </div>
      <div className="map-q__actions">
        <button className="mini-btn" aria-label={`${index + 1}번 문제 편집`} onClick={onEdit}>
          <Glyph name="edit" size={19} />
        </button>
        <button className="mini-btn mini-btn--danger" aria-label={`${index + 1}번 문제 삭제`} onClick={onDelete}>
          <Glyph name="delete" size={19} />
        </button>
      </div>
    </div>
  );
}

/** Link that opens 맵 스토어 with the code box already filled in. */
export function mapShareUrl(code: string): string {
  return `${location.origin}${mapPaths.store}?code=${encodeURIComponent(code)}`;
}

function ShareCodeCard({ code, name, isPublic }: { code: string; name: string; isPublic: boolean }) {
  async function copy() {
    const ok = await copyText(code);
    toast(ok ? "코드가 복사되었습니다." : "복사하지 못했어요. 코드를 직접 알려주세요", ok ? "ok" : "error");
  }
  async function share() {
    const url = mapShareUrl(code);
    const text = `상식퀴즈배틀 맵 "${name}" 같이 풀어요! 코드 ${code}`;
    if (typeof navigator.share === "function") {
      try {
        await navigator.share({ title: "상식퀴즈배틀 맵", text, url });
        return;
      } catch (e) {
        if ((e as DOMException)?.name === "AbortError") return;
      }
    }
    const ok = await copyText(`${text}\n${url}`);
    toast(ok ? "링크를 복사했어요" : "복사하지 못했어요. 코드를 직접 알려주세요", ok ? "ok" : "error");
  }
  return (
    <div>
      <div className="code-card">
        <Glyph name="tag" size={22} />
        <div className="code-card__body">
          <div className="code-card__label">공유 코드</div>
          <div className="code-card__code" aria-label={`공유 코드 ${code}`}>{code}</div>
        </div>
        <button className="code-card__btn" onClick={copy} aria-label="코드 복사">
          <Glyph name="copy" size={16} />복사
        </button>
        <button className="code-card__btn" onClick={share} aria-label="링크 공유">
          <Glyph name="share" size={16} />공유
        </button>
      </div>
      {!isPublic ? <div className="map-hint" style={{ marginTop: 6 }}>비공개 맵은 친구가 코드로 받을 수 없어요. '공개 맵'으로 저장해 주세요.</div> : null}
    </div>
  );
}
