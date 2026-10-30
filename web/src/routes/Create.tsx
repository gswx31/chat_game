import { useEffect, useState, type CSSProperties, type FormEvent, type ReactNode } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { friendlyError, questionsApi, roomsApi } from "../api/client";
import { mapsApi, type MapBrief } from "../api/maps";
import { AppBar } from "../components/AppBar";
import { toast } from "../components/feedback";
import { Icon } from "../components/icons";
import { roomPath } from "../lib/paths";
import { SectionCard } from "../components/SectionCard";

/**
 * Create room. `/create?map=<id>` arrives from a card in 퀴즈 맵 with that map already picked
 * (any public map works, not only the ones in 내 맵).
 */
export default function Create() {
  const nav = useNavigate();
  const [params] = useSearchParams();
  const presetId = params.get("map") ?? "";
  const [name, setName] = useState("");
  const [nameErr, setNameErr] = useState<string | null>(null);
  const [isPublic, setIsPublic] = useState(true);
  const [winScore, setWinScore] = useState(20);
  const [roundSeconds, setRoundSeconds] = useState(30);
  const [maxPlayers, setMaxPlayers] = useState(30);
  const [mapId, setMapId] = useState(presetId);
  const [cats, setCats] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState(false);

  const [allCats, setAllCats] = useState<string[] | null>(null);
  const [catsErr, setCatsErr] = useState<string | null>(null);
  const [maps, setMaps] = useState<MapBrief[] | null>(null);
  const [preset, setPreset] = useState<MapBrief | null>(null);

  useEffect(() => {
    questionsApi
      .categories()
      .then(setAllCats)
      .catch((e) => setCatsErr(friendlyError(e)));
    mapsApi
      .listMine()
      .then(setMaps)
      .catch(() => setMaps([])); // a failing map list must never block creating a room
  }, []);

  useEffect(() => {
    if (!presetId) return;
    let alive = true;
    mapsApi
      .get(presetId)
      .then((m) => {
        if (!alive) return;
        setPreset(m);
        setName((cur) => cur || m.name.slice(0, 40));
      })
      .catch(() => {
        if (!alive) return;
        toast("고른 맵을 불러오지 못했어요. 기본 문제로 만들어요.", "error");
        setMapId("");
      });
    return () => {
      alive = false;
    };
  }, [presetId]);

  const mapChoices = [...(maps ?? [])];
  if (preset && !mapChoices.some((m) => m.id === preset.id)) mapChoices.unshift(preset);
  const picked = mapChoices.find((m) => m.id === mapId) ?? null;

  function toggleCat(c: string) {
    setCats((prev) => {
      const next = new Set(prev);
      if (next.has(c)) next.delete(c);
      else next.add(c);
      return next;
    });
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (busy) return;
    if (!name.trim()) {
      setNameErr("방 이름을 입력해주세요.");
      return;
    }
    setNameErr(null);
    setBusy(true);
    try {
      const room = await roomsApi.create({
        name: name.trim(),
        is_public: isPublic,
        win_score: winScore,
        round_seconds: roundSeconds,
        max_players: maxPlayers,
        categories: mapId ? [] : [...cats],
        question_set_id: mapId || null,
      });
      nav(roomPath(room.id), { replace: true });
    } catch (err) {
      toast(friendlyError(err), "error");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="app-page" onSubmit={submit} noValidate>
      <AppBar title="방 만들기" back="/home" />

      <div className="page-body">
        <SectionCard icon="🚪" color="primary" title="방 이름">
          <div className="field">
            <div className="input-icon">
              <span className="input-icon__glyph" aria-hidden>
                <Icon name="edit" size={20} />
              </span>
              <input
                className={`input ${nameErr ? "input--error" : ""}`}
                placeholder="예: 우리반 퀴즈왕"
                value={name}
                maxLength={40}
                onChange={(e) => {
                  setName(e.target.value);
                  if (e.target.value.trim()) setNameErr(null);
                }}
                aria-label="방 이름"
                autoComplete="off"
              />
            </div>
            {nameErr ? <div className="field-error">{nameErr}</div> : null}
            <div className="field__count">{name.length}/40</div>
          </div>
        </SectionCard>

        <SectionCard icon="🗺️" color="purple" title="퀴즈 맵 (선택)" subtitle={mapId ? "고른 맵의 문제만 나와요" : "고르지 않으면 기본 문제에서 나와요"}>
          {picked ? (
            <div className="picked-map">
              <div className="picked-map__body">
                <div className="picked-map__name">{picked.name}</div>
                <div className="picked-map__meta">
                  {picked.item_count}문제 · {picked.creator_nickname}
                </div>
              </div>
              <button type="button" className="btn btn--soft btn--sm" onClick={() => setMapId("")}>
                빼기
              </button>
            </div>
          ) : null}
          {maps === null ? (
            <div className="spinner" style={{ margin: "8px auto" }} />
          ) : mapChoices.length > 0 ? (
            <select className="select" value={mapId} onChange={(e) => setMapId(e.target.value)} aria-label="퀴즈 맵">
              <option value="">기본 문제 사용</option>
              {mapChoices.map((m) => (
                <option key={m.id} value={m.id}>
                  {m.name} ({m.item_count}문항)
                </option>
              ))}
            </select>
          ) : null}
          <div className="picked-links">
            <Link to="/maps/store">퀴즈 맵 둘러보기</Link>
            <Link to="/maps">내 맵 만들기</Link>
          </div>
        </SectionCard>

        {mapId ? null : (
        <SectionCard
          icon="🧩"
          color="red"
          title="카테고리"
          subtitle="선택 안 하면 전체 카테고리 혼합"
          badge={cats.size > 0 ? <span className="pill">{cats.size}개 선택</span> : null}
        >
          {catsErr ? (
            <div className="field-error">{catsErr}</div>
          ) : allCats === null ? (
            <div className="spinner" style={{ margin: "8px auto" }} />
          ) : (
            <div className="chip-row">
              {allCats.map((c) => (
                <button
                  key={c}
                  type="button"
                  className={`chip ${cats.has(c) ? "is-on" : ""}`}
                  aria-pressed={cats.has(c)}
                  onClick={() => toggleCat(c)}
                >
                  {c}
                </button>
              ))}
            </div>
          )}
        </SectionCard>
        )}

        <SectionCard icon="🎚️" color="accent" title="게임 설정">
          <div className="col" style={{ gap: 10 }}>
            <SliderRow icon="🏆" label="목표 점수" value={winScore} unit="점" min={5} max={100} step={5} onChange={setWinScore} />
            <SliderRow icon="⏱️" label="라운드 시간" value={roundSeconds} unit="초" min={10} max={120} step={10} onChange={setRoundSeconds} />
            <SliderRow icon="👥" label="최대 인원" value={maxPlayers} unit="명" min={2} max={200} step={1} onChange={setMaxPlayers} />
          </div>
        </SectionCard>

        <section className="card">
          <div className="section-head" style={{ marginBottom: 0 }}>
            <span className={`icon-box ${isPublic ? "icon-box--blue" : ""}`} style={isPublic ? undefined : { background: "#6b7280" }}>
              {isPublic ? "🌐" : "🔒"}
            </span>
            <div className="section-head__text">
              <div className="section-head__title">{isPublic ? "공개 방" : "비공개 방"}</div>
              <div className="section-head__sub">{isPublic ? "공개방 목록에 보여요" : "방코드를 아는 사람만 들어와요"}</div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={isPublic}
                onChange={(e) => setIsPublic(e.target.checked)}
                aria-label="공개 방"
              />
              <span className="switch__track" />
            </label>
          </div>
        </section>
      </div>

      <div className="bottom-bar">
        <button className="btn btn--block" type="submit" disabled={busy}>
          <Icon name="door" size={22} /> 방 만들기
        </button>
      </div>

      {busy ? (
        <div className="backdrop">
          <div className="card loading-card">
            <div className="spinner" style={{ margin: "0 auto 14px" }} />
            <div style={{ fontWeight: 700 }}>방을 만드는 중...</div>
          </div>
        </div>
      ) : null}
    </form>
  );
}

function SliderRow(props: {
  icon: ReactNode;
  label: string;
  value: number;
  unit: string;
  min: number;
  max: number;
  step: number;
  onChange: (v: number) => void;
}) {
  const pct = ((props.value - props.min) / (props.max - props.min)) * 100;
  return (
    <div className="slider-card">
      <div className="slider-card__top">
        <span aria-hidden>{props.icon}</span>
        <span>{props.label}</span>
        <span className="pill">
          {props.value}
          {props.unit}
        </span>
      </div>
      <input
        className="range"
        type="range"
        min={props.min}
        max={props.max}
        step={props.step}
        value={props.value}
        style={{ "--pct": `${pct}%` } as CSSProperties}
        onChange={(e) => props.onChange(Number(e.target.value))}
        aria-label={props.label}
      />
    </div>
  );
}
