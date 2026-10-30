import { useNavigate } from "react-router-dom";
import { friendlyError } from "../../api/client";
import { mapsApi, type MapBrief } from "../../api/maps";
import { AppBar } from "../../components/AppBar";
import { confirmDialog, toast } from "../../components/feedback";
import { Glyph } from "../../components/Glyph";
import { RequireUser } from "../../components/RequireUser";
import { EmptyView, ErrorView, LoadingView } from "../../components/StateViews";
import { useLoad } from "../../lib/useLoad";
import "../../styles/maps.css";
import { mapPaths } from "./paths";

/** 내 맵: my question sets (mobile/lib/screens/question_sets/question_set_list_screen.dart). */
export default function MapList() {
  return (
    <RequireUser>
      <MapListView />
    </RequireUser>
  );
}

function MapListView() {
  const nav = useNavigate();
  const { data, error, reload } = useLoad(() => mapsApi.listMine());

  async function remove(set: MapBrief) {
    const ok = await confirmDialog({
      title: "맵 삭제",
      content: `"${set.name}" 맵을 삭제할까요?\n되돌릴 수 없습니다.`,
      confirmLabel: "삭제",
    });
    if (!ok) return;
    try {
      await mapsApi.remove(set.id);
      toast("맵을 삭제했어요", "ok");
      reload();
    } catch (e) {
      toast(`삭제 실패: ${friendlyError(e)}`, "error");
    }
  }

  return (
    <div className="app-page">
      <AppBar
        title="내 맵"
        actions={
          <button className="appbar__text-btn" onClick={() => nav(mapPaths.store)}>
            <span style={{ display: "inline-flex", alignItems: "center", gap: 5 }}>
              <Glyph name="store" size={18} />
              퀴즈 맵
            </span>
          </button>
        }
      />
      <div className="page-body">
        {data ? (
          data.length === 0 ? (
            <EmptyView icon="map" title="아직 만든 맵이 없어요">
              오른쪽 아래 버튼으로 새 맵을 만들어보세요!
            </EmptyView>
          ) : (
            <div className="list" style={{ gap: 12 }}>
              {data.map((set) => (
                <MapCard key={set.id} set={set} onOpen={() => nav(mapPaths.edit(set.id))} onDelete={() => remove(set)} />
              ))}
            </div>
          )
        ) : error ? (
          <ErrorView message={error} onRetry={reload} />
        ) : (
          <LoadingView />
        )}
      </div>
      <div className="map-fab-dock">
        <button className="map-fab" onClick={() => nav(mapPaths.create)}>
          <Glyph name="add" size={22} />새 맵 만들기
        </button>
      </div>
    </div>
  );
}

function MapCard({ set, onOpen, onDelete }: { set: MapBrief; onOpen: () => void; onDelete: () => void }) {
  return (
    <div className="map-card" onClick={onOpen}>
      <div className="map-card__top">
        <Glyph name="map" size={18} />
        <div className="map-card__name">{set.name}</div>
        <span className="count-pill">{set.item_count}문제</span>
      </div>
      {set.description ? <div className="map-card__desc">{set.description}</div> : null}
      {set.tags.length > 0 ? (
        <div className="map-tags">
          {set.tags.map((t) => (
            <span key={t} className="map-tag">
              {t}
            </span>
          ))}
        </div>
      ) : null}
      <div className="map-card__meta">
        <span>
          <Glyph name={set.is_public ? "public" : "lock"} size={14} />
          {set.is_public ? "공개" : "비공개"}
        </span>
        <span>
          <Glyph name="play" size={14} />
          {set.play_count}회 플레이
        </span>
        <span className="map-card__end">
          <button
            className="map-card__del"
            aria-label={`${set.name} 삭제`}
            onClick={(e) => {
              e.stopPropagation();
              onDelete();
            }}
          >
            <Glyph name="delete" size={20} />
          </button>
          <button
            className="map-card__edit"
            aria-label={`${set.name} 편집`}
            onClick={(e) => {
              e.stopPropagation();
              onOpen();
            }}
          >
            편집 →
          </button>
        </span>
      </div>
    </div>
  );
}
