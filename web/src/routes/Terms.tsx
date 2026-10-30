import { AppBar } from "../components/AppBar";
import { TERMS_VERSION } from "../store/terms";
import "../styles/safety.css";

/** Optional: set VITE_CONTACT_EMAIL at build time to show a contact line. Nothing is invented. */
const CONTACT = (import.meta.env.VITE_CONTACT_EMAIL as string | undefined)?.trim();

/** 이용약관·운영정책 (public page, linked from the sign-in screen and the store listing). */
export default function Terms() {
  return (
    <div className="app-page">
      <AppBar title="이용약관·운영정책" back="/" />
      <div className="page-body">
        <article className="terms">
          <p className="muted">시행일 {TERMS_VERSION}</p>

          <h2>1. 서비스</h2>
          <p>상식퀴즈배틀은 친구와 채팅으로 정답을 겨루는 실시간 상식 퀴즈 게임입니다. 회원가입 없이 닉네임만으로 이용할 수 있어요.</p>

          <h2>2. 이렇게 이용해 주세요</h2>
          <p>닉네임, 채팅, 직접 만든 퀴즈 맵 모두 아래 행동은 금지돼요.</p>
          <ul>
            <li>욕설, 비하, 괴롭힘, 혐오 표현</li>
            <li>음란하거나 선정적인 내용(닉네임 포함)</li>
            <li>도배, 광고, 사기, 개인정보를 묻거나 퍼뜨리는 행동</li>
            <li>정답을 퍼뜨리거나 게임 진행을 일부러 방해하는 행동</li>
            <li>타인의 저작물(노래 가사, 문제집 등)을 허락 없이 퀴즈 맵에 올리는 행동</li>
          </ul>

          <h2>3. 신고·차단과 조치</h2>
          <ul>
            <li>채팅 줄 옆 “⋯”나 참가자 목록에서 상대를 신고하거나 차단할 수 있어요. 신고는 상대에게 알려지지 않아요.</li>
            <li>차단하면 그 사람의 채팅이 더 이상 보이지 않아요. 설정의 “차단한 사용자”에서 풀 수 있어요.</li>
            <li>신고는 운영자가 직접 확인해요. 바로 처리되지 않을 수 있고, 규칙을 어긴 것으로 확인되면 일정 기간 접속·입장을 제한해요.</li>
          </ul>

          <h2>4. 수집하는 정보</h2>
          <ul>
            <li>닉네임, 기기에서 만든 임의의 식별값(게스트 로그인용), 게임 결과(점수·순위), 내가 만든 퀴즈 맵</li>
            <li>신고·차단 내역. 신고할 때 첨부된 채팅 한 줄과 설명은 운영자 확인을 위해 저장돼요.</li>
            <li>채팅 내용은 따로 저장하지 않아요. 방에 있는 사람에게 전달되면 서버에 남지 않아요.</li>
            <li>서비스 운영과 보안을 위해 접속 기록(IP 등)이 서버 로그에 남을 수 있어요.</li>
          </ul>
          <p>수집한 정보는 게임 제공, 전적 표시, 신고 처리에만 쓰고 광고 목적으로 제3자에게 넘기지 않아요.</p>

          <h2>5. 기타</h2>
          <ul>
            <li>서비스는 예고 없이 바뀌거나 중단될 수 있어요.</li>
            <li>이 약관은 필요하면 바뀌고, 중요한 변경은 다시 동의를 받아요.</li>
          </ul>

          {CONTACT ? (
            <>
              <h2>문의</h2>
              <p>
                신고 처리, 정보 삭제 요청 등 문의는 <a href={`mailto:${CONTACT}`}>{CONTACT}</a> 로 보내 주세요.
              </p>
            </>
          ) : null}
        </article>
      </div>
    </div>
  );
}
