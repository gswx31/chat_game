import { useState, type FormEvent } from "react";
import { api, friendlyError, type TokenResponse } from "../api/client";
import { AppBar } from "../components/AppBar";
import { Avatar } from "../components/Avatar";
import { toast, confirmDialog } from "../components/feedback";
import { Glyph } from "../components/Glyph";
import { RequireUser } from "../components/RequireUser";
import { useGoBack } from "../lib/nav";
import { useAuth } from "../store/auth";
import "../styles/maps.css";

const MAX_NICKNAME = 20; // same limit as the app's text field

/** 내 프로필: change the nickname (mobile/lib/mypage/my_page_screen.dart). */
export default function Profile() {
  return (
    <RequireUser>
      <ProfileView />
    </RequireUser>
  );
}

function ProfileView() {
  const user = useAuth((s) => s.user)!;
  const signIn = useAuth((s) => s.signIn);
  const goBack = useGoBack("/settings");
  const [name, setName] = useState(user.nickname);
  const [saving, setSaving] = useState(false);
  const dirty = name.trim() !== user.nickname;

  async function leave() {
    if (dirty) {
      const ok = await confirmDialog({
        title: "변경 취소",
        content: "저장하지 않은 변경 사항이 있습니다. 나가시겠습니까?",
        confirmLabel: "나가기",
        cancelLabel: "계속 편집",
        danger: false,
      });
      if (!ok) return;
    }
    goBack();
  }

  async function save(e: FormEvent) {
    e.preventDefault();
    if (saving) return;
    const n = name.trim();
    if (!n) {
      toast("닉네임을 입력해주세요.", "error");
      return;
    }
    if (n !== user.nickname) {
      setSaving(true);
      try {
        // the response carries a fresh token that already has the new nickname in it
        const r = await api<TokenResponse>("/auth/me", { method: "PATCH", json: { nickname: n } });
        signIn(r.access_token, { user_id: r.user_id, nickname: r.nickname });
      } catch (err) {
        setSaving(false);
        toast(`저장 실패: ${friendlyError(err)}`, "error");
        return;
      }
      setSaving(false);
    }
    toast("프로필이 저장되었습니다.", "ok");
    goBack();
  }

  return (
    <div className="app-page">
      <div className="profile-hero">
        <AppBar
          title="내 프로필"
          onBack={leave}
          actions={
            saving ? (
              <span className="appbar__busy">
                <span className="spinner spinner--white" role="status" aria-label="저장 중" />
              </span>
            ) : null
          }
        />
        <div className="profile-hero__avatar">
          <Avatar name={user.nickname} size="xl" onBrand />
        </div>
        <div className="profile-hero__name">{user.nickname}</div>
      </div>

      <form className="page-body" onSubmit={save}>
        <section className="card">
          <div className="section-head">
            <span className="icon-box icon-box--primary">
              <Glyph name="person" size={20} />
            </span>
            <div className="section-head__text">
              <div className="section-head__title">닉네임</div>
              <div className="section-head__sub">게임에서 다른 친구들에게 보이는 이름이에요</div>
            </div>
          </div>
          <div className="field">
            <div className="input-icon">
              <span className="input-icon__glyph">
                <Glyph name="person" size={20} />
              </span>
              <input
                className="input"
                value={name}
                maxLength={MAX_NICKNAME}
                placeholder="사용할 닉네임 입력"
                aria-label="닉네임"
                autoComplete="nickname"
                enterKeyHint="done"
                onChange={(e) => setName(e.target.value)}
              />
            </div>
            <span className="field__count">
              {name.length}/{MAX_NICKNAME}
            </span>
          </div>
          <button className="btn btn--block" type="submit" disabled={saving} style={{ marginTop: 6 }}>
            저장하기
          </button>
        </section>
      </form>
    </div>
  );
}
