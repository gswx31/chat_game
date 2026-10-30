import { useState } from "react";
import { useTerms } from "../store/terms";
import "../styles/safety.css";

/** Checkbox + link used by the sign-in form and the gate below. */
export function TermsConsent({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="terms-consent">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <span>
        <a href="/terms" target="_blank" rel="noopener noreferrer">
          이용약관·운영정책
        </a>
        에 동의합니다 (필수)
      </span>
    </label>
  );
}

/**
 * Shown once to players who already have a session but have not agreed to the terms yet
 * (anyone who signed in before the terms existed).
 */
export function TermsGate() {
  const accept = useTerms((s) => s.accept);
  const [ok, setOk] = useState(false);
  return (
    <div className="signin">
      <div className="signin__col">
        <div className="signin__hero anim-up">
          <img className="signin__logo" src="/img/logo.png" alt="" width={72} height={72} />
          <h1 className="signin__title">이용 규칙을 확인해 주세요</h1>
          <p className="signin__sub">
            함께 즐기려면 서로 지켜야 할 규칙이 있어요.
            <br />
            욕설·음란·도배 등은 신고·차단할 수 있고, 반복되면 이용이 제한돼요.
          </p>
        </div>
        <div className="signin__sheet card anim-up">
          <TermsConsent checked={ok} onChange={setOk} />
          <button className="btn btn--block" style={{ marginTop: 14 }} disabled={!ok} onClick={accept}>
            동의하고 계속하기
          </button>
        </div>
      </div>
    </div>
  );
}
