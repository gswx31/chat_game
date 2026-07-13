import { Outlet, Link, useNavigate } from "react-router-dom";
import { useAuth } from "./store/auth";

export default function App() {
  const { user, signOut } = useAuth();
  const nav = useNavigate();

  function handleSignOut() {
    signOut();
    nav("/");
  }

  return (
    <div className="app">
      <header className="topbar">
        <Link to={user ? "/lobby" : "/"} className="brand">
          <span className="brand-dot" />
          상식퀴즈배틀
          <span className="brand-sub">상배</span>
        </Link>

        {user && (
          <div className="row">
            <span className="muted" style={{ fontSize: 14, fontWeight: 600 }}>
              {user.nickname}
            </span>
            <button className="btn-ghost btn-sm" onClick={handleSignOut}>
              로그아웃
            </button>
          </div>
        )}
      </header>
      <main className="main">
        <Outlet />
      </main>
    </div>
  );
}
