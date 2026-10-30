import type { ReactNode } from "react";
import { Fragment } from "react";
import { useNavigate } from "react-router-dom";
import { AppBar } from "../components/AppBar";
import { Avatar } from "../components/Avatar";
import { confirmDialog, toast } from "../components/feedback";
import { Glyph, type GlyphName } from "../components/Glyph";
import { RequireUser } from "../components/RequireUser";
import { copyText } from "../lib/share";
import { useAuth } from "../store/auth";
import { usePrefs } from "../store/prefs";
import { mapPaths } from "./maps/paths";
import "../styles/maps.css";

const APP_VERSION = "1.0.0"; // same as the app's 버전 정보 row

/** 설정 (mobile/lib/settings_screen.dart). Rows marked "web" do not exist in the app. */
export default function Settings() {
  return (
    <RequireUser>
      <SettingsView />
    </RequireUser>
  );
}

function SettingsView() {
  const nav = useNavigate();
  const user = useAuth((s) => s.user)!;
  const signOut = useAuth((s) => s.signOut);
  const sound = usePrefs((s) => s.sound);
  const setSound = usePrefs((s) => s.setSound);

  async function shareApp() {
    const url = `${location.origin}/`;
    const text = "상식퀴즈배틀 같이 해요!";
    if (typeof navigator.share === "function") {
      try {
        await navigator.share({ title: "상식퀴즈배틀", text, url });
        return;
      } catch (e) {
        if ((e as DOMException)?.name === "AbortError") return; // the user closed the share sheet
      }
    }
    const ok = await copyText(`${text}\n${url}`);
    toast(ok ? "링크를 복사했어요" : "복사하지 못했어요. 주소창의 링크를 알려주세요", ok ? "ok" : "error");
  }

  async function logout() {
    const ok = await confirmDialog({
      title: "로그아웃",
      content: "이 기기에서 로그아웃할까요?\n같은 기기로 다시 들어오면 내 전적과 맵은 그대로 이어져요.",
      confirmLabel: "로그아웃",
    });
    if (!ok) return;
    signOut();
    nav("/", { replace: true });
  }

  return (
    <div className="app-page">
      <div className="profile-hero">
        <AppBar title="설정" />
        <div className="profile-hero__avatar">
          <Avatar name={user.nickname} size="lg" onBrand />
        </div>
        <div className="profile-hero__name">{user.nickname}</div>
        <button className="profile-hero__chip" onClick={() => nav("/profile")}>
          <Glyph name="edit" size={13} />
          프로필 수정
        </button>
      </div>

      <div className="page-body page-body--tight">
        <div className="section-label section-label--ko" style={{ paddingTop: 6 }}>계정</div>
        <TileGroup>
          <Tile icon="person" color="primary" title="내 프로필" onClick={() => nav("/profile")} />
          <Tile icon="map" color="accent" title="내 맵" sub="커스텀 퀴즈 세트 관리" onClick={() => nav(mapPaths.list)} />
          <Tile icon="trophy" color="orange" title="내 전적" sub="지금까지 한 게임" onClick={() => nav("/history")} />
        </TileGroup>

        <div className="section-label section-label--ko">앱</div>
        <TileGroup>
          <label className="set-tile set-tile--static">
            <span className="icon-box icon-box--blue"><Glyph name="volume" size={20} /></span>
            <span className="set-tile__body">
              <span className="set-tile__title">정답 효과음</span>
              <span className="set-tile__sub" style={{ display: "block" }}>정답이 나오면 소리가 나요</span>
            </span>
            <span className="switch">
              <input type="checkbox" role="switch" checked={sound} onChange={(e) => setSound(e.target.checked)} aria-label="정답 효과음" />
              <span className="switch__track" />
            </span>
          </label>
          <Tile icon="share" color="purple" title="친구에게 링크 보내기" sub="이 주소로 들어오면 바로 같이 할 수 있어요" onClick={shareApp} />
          <Tile icon="info" color="grey" title="버전 정보" value={APP_VERSION} />
        </TileGroup>

        <div className="section-label section-label--ko">안전</div>
        <TileGroup>
          <Tile icon="person" color="red" title="차단한 사용자" sub="차단을 풀거나 목록을 확인해요" onClick={() => nav("/blocked")} />
          <Tile icon="info" color="grey" title="이용약관·운영정책" sub="신고·차단과 조치 기준" onClick={() => nav("/terms")} />
        </TileGroup>

        <div style={{ height: 12 }} />
        <TileGroup>
          <Tile icon="logout" color="red" title="로그아웃" danger onClick={logout} />
        </TileGroup>
      </div>
    </div>
  );
}

function TileGroup({ children }: { children: ReactNode[] | ReactNode }) {
  const items = Array.isArray(children) ? children : [children];
  return (
    <div className="set-group">
      {items.map((c, i) => (
        <Fragment key={i}>
          {i > 0 ? <hr /> : null}
          {c}
        </Fragment>
      ))}
    </div>
  );
}

interface TileProps {
  icon: GlyphName;
  color: string;
  title: string;
  sub?: string;
  value?: string;
  danger?: boolean;
  onClick?: () => void;
}

function Tile({ icon, color, title, sub, value, danger, onClick }: TileProps) {
  return (
    <button
      type="button"
      className={`set-tile ${danger ? "set-tile--danger" : ""} ${onClick ? "" : "set-tile--static"}`}
      onClick={onClick}
      disabled={!onClick}
    >
      <span className={`icon-box icon-box--${color}`}>
        <Glyph name={icon} size={20} />
      </span>
      <span className="set-tile__body">
        <span className="set-tile__title">{title}</span>
        {sub ? <span className="set-tile__sub" style={{ display: "block" }}>{sub}</span> : null}
      </span>
      {value ? <span className="set-tile__value">{value}</span> : null}
      {onClick && !danger ? (
        <span className="set-tile__chev">
          <Glyph name="chevron" size={20} />
        </span>
      ) : null}
    </button>
  );
}
