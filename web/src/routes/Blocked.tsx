import { useState } from "react";
import { friendlyError } from "../api/client";
import { safetyApi, type BlockedUser } from "../api/safety";
import { AppBar } from "../components/AppBar";
import { Avatar } from "../components/Avatar";
import { toast } from "../components/feedback";
import { RequireUser } from "../components/RequireUser";
import { EmptyView, ErrorView, LoadingView } from "../components/StateViews";
import { useLoad } from "../lib/useLoad";
import { useBlocked } from "../store/blocked";
import "../styles/safety.css";

/** 차단한 사용자: who I blocked, with a way to undo it. */
export default function Blocked() {
  return (
    <RequireUser>
      <BlockedView />
    </RequireUser>
  );
}

function BlockedView() {
  const { data, error, loading, reload } = useLoad(() => safetyApi.blocks());
  const [gone, setGone] = useState<Set<string>>(new Set());

  async function unblock(u: BlockedUser) {
    try {
      await useBlocked.getState().unblock(u.user_id);
      setGone((s) => new Set(s).add(u.user_id));
      toast(`${u.nickname}님 차단을 풀었어요`, "ok");
    } catch (e) {
      toast(friendlyError(e), "error");
    }
  }

  const rows = (data ?? []).filter((u) => !gone.has(u.user_id));

  return (
    <div className="app-page">
      <AppBar title="차단한 사용자" back="/settings" />
      <div className="page-body">
        {data ? (
          rows.length === 0 ? (
            <EmptyView icon="person" title="차단한 사용자가 없어요">
              채팅 줄 옆의 “⋯”에서
              <br />
              신고하거나 차단할 수 있어요.
            </EmptyView>
          ) : (
            <div className="card" style={{ padding: "4px 16px" }}>
              {rows.map((u) => (
                <div key={u.user_id} className="blocked-row">
                  <Avatar name={u.nickname} />
                  <div className="grow">
                    <div className="blocked-row__name">{u.nickname}</div>
                    <div className="blocked-row__date">{new Date(u.blocked_at).toLocaleDateString("ko-KR")} 차단</div>
                  </div>
                  <button className="btn btn--sm btn--ghost" onClick={() => unblock(u)}>
                    차단 해제
                  </button>
                </div>
              ))}
            </div>
          )
        ) : error ? (
          <ErrorView message={error} onRetry={reload} />
        ) : loading ? (
          <LoadingView />
        ) : null}
      </div>
    </div>
  );
}
