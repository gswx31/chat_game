import { useEffect, useState } from "react";
import { friendlyError } from "../api/client";
import { REPORT_REASONS, safetyApi, type ReportReason } from "../api/safety";
import { useBlocked } from "../store/blocked";
import { Avatar } from "./Avatar";
import { confirmDialog, toast } from "./feedback";
import { SheetModal } from "./SheetModal";
import "../styles/safety.css";

export interface SafetyTarget {
  user_id: string;
  nickname: string;
  /** the chat line the player tapped (sent along with a report) */
  message?: string;
}

interface Props {
  target: SafetyTarget;
  roomCode?: string;
  onClose: () => void;
}

/**
 * What you can do about another player: report them, block them (or unblock). Opened from the
 * "⋯" next to a chat line and from the participant lists.
 */
export function SafetySheet({ target, roomCode, onClose }: Props) {
  const blocked = useBlocked((s) => target.user_id in s.at);
  const [step, setStep] = useState<"menu" | "report">("menu");

  // the block may have been changed in another tab since this screen last asked
  useEffect(() => {
    void useBlocked.getState().load();
  }, []);

  async function toggleBlock() {
    if (blocked) {
      try {
        await useBlocked.getState().unblock(target.user_id);
        toast(`${target.nickname}님 차단을 풀었어요`, "ok");
        onClose();
      } catch (e) {
        toast(friendlyError(e), "error");
      }
      return;
    }
    const ok = await confirmDialog({
      title: `${target.nickname}님을 차단할까요?`,
      content: "이 사람의 채팅이 더 이상 보이지 않아요. 설정 > 차단한 사용자에서 언제든 풀 수 있어요.",
      confirmLabel: "차단",
    });
    if (!ok) return;
    try {
      await useBlocked.getState().block(target.user_id);
      toast(`${target.nickname}님을 차단했어요`, "ok");
      onClose();
    } catch (e) {
      toast(friendlyError(e), "error");
    }
  }

  if (step === "report") {
    return <ReportForm target={target} roomCode={roomCode} blocked={blocked} onClose={onClose} />;
  }

  return (
    <SheetModal title={target.nickname} onClose={onClose}>
      <div className="safety-who">
        <Avatar name={target.nickname} size="lg" />
        {target.message ? <div className="safety-quote">“{target.message}”</div> : null}
      </div>
      <div className="safety-actions">
        <button className="safety-action safety-action--danger" onClick={() => setStep("report")}>
          <span className="safety-action__icon" aria-hidden>
            🚩
          </span>
          <span className="safety-action__body">
            <b>신고하기</b>
            <span>운영자가 확인하고 필요하면 이용을 제한해요</span>
          </span>
        </button>
        <button className="safety-action" onClick={toggleBlock}>
          <span className="safety-action__icon" aria-hidden>
            {blocked ? "✅" : "🚫"}
          </span>
          <span className="safety-action__body">
            <b>{blocked ? "차단 해제" : "차단하기"}</b>
            <span>{blocked ? "다시 이 사람의 채팅이 보여요" : "이 사람의 채팅이 보이지 않아요"}</span>
          </span>
        </button>
      </div>
      <button className="btn btn--ghost btn--block" onClick={onClose}>
        닫기
      </button>
    </SheetModal>
  );
}

function ReportForm({ target, roomCode, blocked, onClose }: { target: SafetyTarget; roomCode?: string; blocked: boolean; onClose: () => void }) {
  const [reason, setReason] = useState<ReportReason | null>(null);
  const [detail, setDetail] = useState("");
  const [alsoBlock, setAlsoBlock] = useState(!blocked);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const needsDetail = reason === "other";
  const ready = reason !== null && (!needsDetail || detail.trim().length >= 2);

  async function submit() {
    if (!ready || !reason || busy) return;
    setBusy(true);
    setErr(null);
    try {
      await safetyApi.report({
        target_user_id: target.user_id,
        reason,
        detail: detail.trim() || undefined,
        message_text: target.message,
        room_code: roomCode || undefined,
      });
    } catch (e) {
      setErr(friendlyError(e));
      setBusy(false);
      return;
    }
    // the report is in; blocking is a courtesy on top of it, so a failure there is not an error
    let blockedNow = false;
    if (alsoBlock && !blocked) {
      try {
        await useBlocked.getState().block(target.user_id);
        blockedNow = true;
      } catch {
        /* reported anyway */
      }
    }
    toast(blockedNow ? "신고가 접수됐고 차단했어요" : "신고가 접수됐어요. 확인 후 조치할게요", "ok");
    onClose();
  }

  return (
    <SheetModal title={`${target.nickname}님 신고`} subtitle="어떤 문제인가요? 신고는 상대에게 알려지지 않아요" onClose={onClose}>
      {target.message ? <div className="safety-quote safety-quote--box">“{target.message}”</div> : null}

      <div className="safety-reasons" role="radiogroup" aria-label="신고 사유">
        {REPORT_REASONS.map((r) => (
          <label key={r.value} className={`safety-reason ${reason === r.value ? "is-on" : ""}`}>
            <input type="radio" name="reason" value={r.value} checked={reason === r.value} onChange={() => setReason(r.value)} />
            <span className="safety-reason__dot" aria-hidden />
            <span className="safety-reason__body">
              <b>{r.label}</b>
              <span>{r.hint}</span>
            </span>
          </label>
        ))}
      </div>

      <div className="field">
        <label className="field__label" htmlFor="report-detail">
          자세한 내용 <span className="muted">{needsDetail ? "(필수)" : "(선택)"}</span>
        </label>
        <textarea
          id="report-detail"
          className="input safety-textarea"
          value={detail}
          maxLength={300}
          rows={3}
          placeholder="운영자가 확인하는 데 도움이 되는 내용을 적어 주세요"
          onChange={(e) => setDetail(e.target.value)}
        />
        <span className="field__count">{detail.length}/300</span>
      </div>

      {!blocked ? (
        <label className="safety-check">
          <input type="checkbox" checked={alsoBlock} onChange={(e) => setAlsoBlock(e.target.checked)} />
          <span>이 사용자도 차단하기 (채팅이 보이지 않아요)</span>
        </label>
      ) : null}

      {err ? <div className="field-error">{err}</div> : null}

      <button className="btn btn--danger btn--block" disabled={!ready || busy} onClick={submit}>
        {busy ? "보내는 중..." : "신고하기"}
      </button>
    </SheetModal>
  );
}
