import { copyCode, shareInvite } from "../lib/share";
import { Icon } from "./icons";

/**
 * Friend invitation: the room code, big, plus "초대 링크 공유" (phone share sheet, or copy)
 * and "코드 복사". Used in the lobby and in the in-game invite sheet.
 */
export function InviteBox({ code }: { code: string }) {
  if (!code) return null;
  return (
    <section className="invite card">
      <div className="invite__label">👋 친구 초대하기</div>
      <button className="invite__code mono" onClick={() => copyCode(code)} aria-label={`방 코드 ${code} 복사`}>
        {code}
      </button>
      <div className="invite__hint">링크를 보내면 누르는 순간 이 방으로 들어와요</div>
      <div className="invite__actions">
        <button className="btn btn--sm grow" onClick={() => shareInvite(code)}>
          <Icon name="link" size={18} /> 초대 링크 공유
        </button>
        <button className="btn btn--sm btn--soft" onClick={() => copyCode(code)}>
          <Icon name="copy" size={16} /> 코드 복사
        </button>
      </div>
    </section>
  );
}
