import { historyApi, formatPlayedAt, rankLabel, type HistoryItem, type HistorySummary } from "../api/history";
import { AppBar } from "../components/AppBar";
import { Glyph } from "../components/Glyph";
import { RequireUser } from "../components/RequireUser";
import { EmptyView, ErrorView, LoadingView } from "../components/StateViews";
import { useLoad } from "../lib/useLoad";
import "../styles/maps.css";

/** 내 전적: 누적 숫자(판 수·우승·점수) + 최근 판 목록 (mobile/lib/screens/history_screen.dart). */
export default function History() {
  return (
    <RequireUser>
      <HistoryView />
    </RequireUser>
  );
}

function HistoryView() {
  const { data, error, loading, reload } = useLoad(() => historyApi.mine());

  return (
    <div className="app-page">
      <AppBar
        title="내 전적"
        actions={
          <button className="icon-btn" aria-label="새로고침" onClick={reload} disabled={loading}>
            <Glyph name="refresh" size={22} />
          </button>
        }
      />
      <div className="page-body">
        {data ? (
          data.games === 0 ? (
            <EmptyView icon="trophy" title="아직 끝난 게임이 없어요">
              친구와 한 판 하고 나면 여기에 쌓여요.
              <br />
              (점수를 낸 게임만 기록돼요)
            </EmptyView>
          ) : (
            <HistoryList summary={data} />
          )
        ) : error ? (
          <ErrorView message={error} onRetry={reload} />
        ) : (
          <LoadingView />
        )}
      </div>
    </div>
  );
}

function HistoryList({ summary }: { summary: HistorySummary }) {
  const truncated = summary.items.length < summary.games;
  return (
    <>
      <div className="stat-card">
        <Stat label="플레이" value={`${summary.games}판`} />
        <div className="stat-card__sep" />
        <Stat label="우승" value={`${summary.wins}회`} />
        <div className="stat-card__sep" />
        <Stat label="누적 점수" value={`${summary.total_score}점`} />
      </div>
      <div className="hist-group-title">최근 게임</div>
      <div className="list" style={{ gap: 10 }}>
        {summary.items.map((item) => (
          <HistoryTile key={item.id} item={item} />
        ))}
      </div>
      {truncated ? <div className="hist-footnote">최근 {summary.items.length}판만 보여드려요.</div> : null}
    </>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="stat-card__item">
      <div className="stat-card__value">{value}</div>
      <div className="stat-card__label">{label}</div>
    </div>
  );
}

function HistoryTile({ item }: { item: HistoryItem }) {
  let detail = `${item.player_count}명 · ${item.win_score}점 먼저`;
  if (item.winner_nickname && !item.won) detail += ` · 1등 ${item.winner_nickname}`;
  const medal = item.rank <= 3;
  return (
    <div className="history-tile">
      <div className={`history-tile__rank ${medal ? "history-tile__rank--medal" : ""}`}>{rankLabel(item.rank)}</div>
      <div className="history-tile__body">
        <div className="history-tile__title">
          <span className="history-tile__name">{item.room_name}</span>
          {item.won ? <span className="badge-win">우승</span> : null}
        </div>
        <div className="history-tile__meta">{detail}</div>
        <div className="history-tile__meta" style={{ marginTop: 0 }}>
          {formatPlayedAt(item.played_at)}
        </div>
      </div>
      <div className="history-tile__score">{item.score}점</div>
    </div>
  );
}
