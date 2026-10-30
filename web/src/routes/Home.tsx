import { Link, useNavigate } from "react-router-dom";
import { Avatar } from "../components/Avatar";
import { BrandBlock } from "../components/Brand";
import { Glyph, type GlyphName } from "../components/Glyph";
import { Icon } from "../components/icons";
import { useAuth } from "../store/auth";

const FEATURES: { to: string; icon: GlyphName; title: string; text: string; cta: string }[] = [
  { to: "/join", icon: "search", title: "공개방 찾기", text: "지금 열려 있는 방에 바로 들어가요.", cta: "공개방 찾기" },
  { to: "/create", icon: "add", title: "방 만들기", text: "주제를 고르고 방을 열어 친구를 불러요.", cta: "방 만들기" },
  { to: "/join?code=1", icon: "tag", title: "코드로 참가", text: "친구에게 받은 6자리 방코드로 입장해요.", cta: "코드 입력" },
  { to: "/maps/store", icon: "map", title: "퀴즈 맵", text: "분야별 심화 맵과 친구들이 만든 맵을 골라요.", cta: "맵 둘러보기" },
];

/** Home: the brand, a headline and the four things you can do, each on its own card. */
export default function Home() {
  const user = useAuth((s) => s.user);
  const nav = useNavigate();
  const name = user?.nickname ?? "게스트";

  return (
    <div className="home">
      <div className="home__col">
        <div className="home__top">
          <Link to="/maps" className="pill-btn pill-btn--pink">
            <Glyph name="edit" size={18} /> 맵 만들기
          </Link>
          <div className="home__top-end">
            <button className="pill-btn home__me" aria-label="내 프로필" onClick={() => nav("/profile")}>
              <Avatar name={name} size="sm" />
              <span className="home__me-name">{name}</span>
            </button>
            <button className="pill-btn" style={{ padding: "0 10px" }} aria-label="설정" onClick={() => nav("/settings")}>
              <Icon name="settings" size={20} />
            </button>
          </div>
        </div>

        <div className="home__hero anim-up">
          <BrandBlock />
          <h1 className="headline">
            채팅창에 먼저 치면 정답!
            <br />
            실시간 상식 퀴즈 배틀
          </h1>
          <p className="headline__sub">{name}님, 오늘도 친구들이랑 한 판 해볼래요?</p>
        </div>

        <div className="feature-grid anim-up">
          {FEATURES.map((f) => (
            <div key={f.title} className="feature-card">
              <span className="feature-card__icon">
                <Glyph name={f.icon} size={36} />
              </span>
              <h2 className="feature-card__title">{f.title}</h2>
              <p className="feature-card__text">{f.text}</p>
              <Link to={f.to} className="btn">
                {f.cta}
              </Link>
            </div>
          ))}
        </div>

        <div className="home__links">
          <Link to="/history" className="pill-btn">
            <Glyph name="trophy" size={18} /> 내 전적
          </Link>
          <Link to="/maps" className="pill-btn">
            <Glyph name="list" size={18} /> 내 맵
          </Link>
        </div>
      </div>
    </div>
  );
}
