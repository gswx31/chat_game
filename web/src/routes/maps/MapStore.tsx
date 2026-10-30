import { useEffect, useRef, useState, type FormEvent } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { ApiError, friendlyError, questionsApi } from "../../api/client";
import { mapsApi, type BrowseSort, type MapBrief, type MapDetail } from "../../api/maps";
import { AppBar } from "../../components/AppBar";
import { toast } from "../../components/feedback";
import { Glyph } from "../../components/Glyph";
import { RequireUser } from "../../components/RequireUser";
import { EmptyView, ErrorView, LoadingView } from "../../components/StateViews";
import { SheetModal } from "../../components/SheetModal";
import { useLoad } from "../../lib/useLoad";
import { useAuth } from "../../store/auth";
import "../../styles/maps.css";

const PAGE = 20; // same page size as the app

interface Filters {
  q: string;
  sort: BrowseSort;
  tag: string | null;
}

/** 퀴즈 맵 목록: browse public maps, open a room with one, or copy it into 내 맵. */
export default function MapStore() {
  return (
    <RequireUser>
      <MapStoreView />
    </RequireUser>
  );
}

function MapStoreView() {
  const me = useAuth((s) => s.user)!;
  const [params, setParams] = useSearchParams();
  const [qInput, setQInput] = useState("");
  const [filters, setFilters] = useState<Filters>({ q: "", sort: "popular", tag: null });
  const [sets, setSets] = useState<MapBrief[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [busy, setBusy] = useState<Set<string>>(new Set());
  const [done, setDone] = useState<Set<string>>(new Set());
  const [codeOpen, setCodeOpen] = useState(() => params.has("code")); // arrived through a shared link
  const seq = useRef(0);
  const themes = useLoad(() => questionsApi.categories()).data ?? []; // until loaded: only "전체"

  async function fetchPage(f: Filters, offset: number) {
    const mine = ++seq.current;
    setLoading(true);
    setError(null);
    try {
      const rows = await mapsApi.browse({ q: f.q || undefined, tag: f.tag ?? undefined, sort: f.sort, offset, limit: PAGE });
      if (mine !== seq.current) return;
      setSets((cur) => (offset === 0 ? rows : [...cur, ...rows]));
      setHasMore(rows.length === PAGE);
    } catch (e) {
      if (mine !== seq.current) return;
      // a failed "더 불러오기" keeps the rows already on screen
      if (offset > 0) toast(`불러오기 실패: ${friendlyError(e)}`, "error");
      else setError(friendlyError(e));
    } finally {
      if (mine === seq.current) setLoading(false);
    }
  }

  useEffect(() => {
    void fetchPage(filters, 0);
    return () => {
      seq.current++;
    };
  }, [filters]);

  function search(e: FormEvent) {
    e.preventDefault();
    setFilters((f) => ({ ...f, q: qInput.trim() }));
  }

  function clearSearch() {
    setQInput("");
    setFilters((f) => ({ ...f, q: "" }));
  }

  async function download(set: MapBrief) {
    setBusy((b) => new Set(b).add(set.id));
    try {
      await mapsApi.clone(set.id);
      setDone((d) => new Set(d).add(set.id));
      toast(`"${set.name}"을(를) 내 맵에 담았어요. 고쳐서 쓸 수 있어요.`, "ok");
    } catch (e) {
      toast(`담기 실패: ${friendlyError(e)}`, "error");
    } finally {
      setBusy((b) => {
        const n = new Set(b);
        n.delete(set.id);
        return n;
      });
    }
  }

  function closeCode() {
    setCodeOpen(false);
    if (params.has("code")) setParams({}, { replace: true });
  }

  return (
    <div className="app-page app-page--wide">
      <AppBar
        title="퀴즈 맵"
        back="/home"
        actions={
          <button className="appbar__text-btn" onClick={() => setCodeOpen(true)}>
            <span style={{ display: "inline-flex", alignItems: "center", gap: 5 }}>
              <Glyph name="tag" size={18} />
              코드로 받기
            </span>
          </button>
        }
      />

      <div className="store-head">
        <form className="store-search" onSubmit={search} role="search">
          <span className="store-search__icon">
            <Glyph name="search" size={20} />
          </span>
          <input
            className="input"
            type="search"
            value={qInput}
            placeholder="맵 이름 검색..."
            aria-label="맵 이름 검색"
            enterKeyHint="search"
            onChange={(e) => setQInput(e.target.value)}
          />
          {qInput ? (
            <button type="button" className="store-search__clear" aria-label="검색어 지우기" onClick={clearSearch}>
              <Glyph name="close" size={18} />
            </button>
          ) : null}
        </form>
        <div className="chip-row" style={{ gap: 8 }}>
          {(["popular", "recent"] as const).map((s) => (
            <button
              key={s}
              className={`chip chip--sm chip--sort ${filters.sort === s ? "is-on" : ""}`}
              aria-pressed={filters.sort === s}
              onClick={() => setFilters((f) => ({ ...f, sort: s }))}
            >
              {s === "popular" ? "인기순" : "최신순"}
            </button>
          ))}
        </div>
        <div className="store-hscroll" role="group" aria-label="테마">
          <button className={`chip chip--sm chip--accent ${filters.tag === null ? "is-on" : ""}`} onClick={() => setFilters((f) => ({ ...f, tag: null }))}>
            전체
          </button>
          {themes.map((t) => (
            <button
              key={t}
              className={`chip chip--sm chip--accent ${filters.tag === t ? "is-on" : ""}`}
              aria-pressed={filters.tag === t}
              onClick={() => setFilters((f) => ({ ...f, tag: f.tag === t ? null : t }))}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      <div className="page-body">
        {sets.length > 0 ? (
          <>
            <div className="qcard-grid">
              {sets.map((set) => (
                <StoreCard
                  key={set.id}
                  set={set}
                  own={set.creator_id === me.user_id}
                  busy={busy.has(set.id)}
                  done={done.has(set.id)}
                  onDownload={() => download(set)}
                />
              ))}
            </div>
            {hasMore ? (
              <div className="store-more">
                <button className="btn btn--soft btn--sm" disabled={loading} onClick={() => fetchPage(filters, sets.length)}>
                  {loading ? <span className="spinner" style={{ margin: 0, width: 18, height: 18, borderWidth: 2 }} /> : "더 불러오기"}
                </button>
              </div>
            ) : null}
          </>
        ) : error ? (
          <ErrorView message={error} onRetry={() => fetchPage(filters, 0)} />
        ) : loading ? (
          <LoadingView />
        ) : (
          <EmptyView icon="search" title="검색 결과가 없습니다" />
        )}
      </div>

      {codeOpen ? <CodeSheet initialCode={params.get("code") ?? ""} onClose={closeCode} /> : null}
    </div>
  );
}

/** One map as a card: title + theme badge, description, and "방 만들기" right on the card. */
function StoreCard({ set, own, busy, done, onDownload }: { set: MapBrief; own: boolean; busy: boolean; done: boolean; onDownload: () => void }) {
  const theme = set.tags.length === 0 ? "종합" : set.tags.length > 2 ? "종합" : set.tags.join("·");
  return (
    <article className="qcard">
      <div className="qcard__head">
        <div className="qcard__titles">
          <h3 className="qcard__title">{set.name}</h3>
          <div className="qcard__by">
            <Glyph name="person" size={13} />
            {set.creator_nickname}
          </div>
        </div>
        <span className="badge">{theme}</span>
      </div>
      <p className={`qcard__desc ${set.description ? "" : "is-empty"}`}>{set.description || "설명 없음"}</p>
      <div className="qcard__foot">
        <span className="qcard__count">
          <b>{set.item_count}</b>문제 · {set.play_count}회 플레이
        </span>
        <div className="qcard__actions">
          {own ? (
            <span className="qcard__tag">내 맵</span>
          ) : done ? (
            <span className="qcard__tag qcard__tag--done">
              <Glyph name="check" size={14} />
              담음
            </span>
          ) : (
            <button className="qcard__save" disabled={busy} onClick={onDownload} aria-label={`${set.name} 내 맵에 담기`} title="내 맵에 담기">
              {busy ? (
                <span className="spinner" style={{ margin: 0, width: 16, height: 16, borderWidth: 2 }} role="status" aria-label="담는 중" />
              ) : (
                <Glyph name="download" size={18} />
              )}
            </button>
          )}
          <Link className="btn btn--sm" to={`/create?map=${encodeURIComponent(set.id)}`}>
            방 만들기
          </Link>
        </div>
      </div>
    </article>
  );
}

/** "코드로 맵 받기": look up a map by its 8-character share code, then copy it. */
function CodeSheet({ initialCode, onClose }: { initialCode: string; onClose: () => void }) {
  const [code, setCode] = useState(initialCode.replace(/[^A-Za-z0-9]/g, "").slice(0, 8).toUpperCase());
  const [searching, setSearching] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const [preview, setPreview] = useState<MapDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function lookup(value = code) {
    const c = value.trim().toUpperCase();
    if (c.length !== 8) {
      setError("코드는 8자리입니다.");
      return;
    }
    setSearching(true);
    setError(null);
    setPreview(null);
    try {
      setPreview(await mapsApi.getByCode(c));
    } catch (e) {
      if (e instanceof ApiError && e.status === 404) setError("맵을 찾을 수 없어요. 코드를 확인해주세요.");
      else if (e instanceof ApiError && e.status === 403) setError("비공개 맵이에요.");
      else setError(`검색 실패: ${friendlyError(e)}`);
    } finally {
      setSearching(false);
    }
  }

  // opened from a shared link: look the map up right away
  useEffect(() => {
    if (code.length === 8) void lookup(code);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function download() {
    if (!preview) return;
    setDownloading(true);
    try {
      await mapsApi.clone(preview.id);
      toast(`"${preview.name}" 다운로드 완료! 내 맵에서 확인하세요.`, "ok");
      onClose();
    } catch (e) {
      toast(`다운로드 실패: ${friendlyError(e)}`, "error");
      setDownloading(false);
    }
  }

  function submit(e: FormEvent) {
    e.preventDefault();
    void lookup();
  }

  return (
    <SheetModal title="코드로 맵 받기" subtitle="공유받은 8자리 코드를 입력하세요" onClose={onClose}>
      <form className="field__row" style={{ marginTop: 18 }} onSubmit={submit}>
        <div className="field">
          <div className="input-icon">
            <span className="input-icon__glyph">
              <Glyph name="tag" size={20} />
            </span>
            <input
              className={`input code-input ${error ? "input--error" : ""}`}
              value={code}
              maxLength={8}
              placeholder="AB12CDEF"
              aria-label="맵 코드"
              autoCapitalize="characters"
              autoCorrect="off"
              spellCheck={false}
              enterKeyHint="search"
              onChange={(e) => {
                setCode(e.target.value.replace(/[^A-Za-z0-9]/g, "").toUpperCase());
                setError(null);
              }}
            />
          </div>
          {error ? <span className="field-error">{error}</span> : null}
        </div>
        <button className="btn" type="submit" disabled={searching} style={{ minHeight: 52, padding: "0 18px" }}>
          {searching ? <span className="spinner spinner--white" role="status" aria-label="검색 중" /> : "검색"}
        </button>
      </form>

      {preview ? (
        <>
          <div className="preview-card">
            <div className="preview-card__name">
              <Glyph name="map" size={16} />
              <span>{preview.name}</span>
            </div>
            {preview.description ? <div className="preview-card__desc">{preview.description}</div> : null}
            <div className="preview-chips">
              <span className="preview-chip">
                <Glyph name="list" size={12} />
                {preview.item_count}문제
              </span>
              <span className="preview-chip">
                <Glyph name="person" size={12} />
                {preview.creator_nickname}
              </span>
              {preview.tags.map((t) => (
                <span key={t} className="preview-chip">
                  {t}
                </span>
              ))}
            </div>
          </div>
          <button className="btn btn--block" onClick={download} disabled={downloading}>
            <Glyph name="download" size={20} />
            {downloading ? "다운로드 중..." : "내 맵으로 다운로드"}
          </button>
        </>
      ) : null}
    </SheetModal>
  );
}
