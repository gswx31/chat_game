import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.web_static import install_web_client


@pytest.fixture
def client(tmp_path):
    (tmp_path / "index.html").write_text("<html>SPA</html>", encoding="utf-8")
    (tmp_path / "assets").mkdir()
    (tmp_path / "assets" / "app.js").write_text("console.log(1)", encoding="utf-8")

    app = FastAPI()

    @app.get("/healthz")
    def healthz():
        return {"status": "ok"}

    @app.get("/rooms/{room_id}")
    def room(room_id: str):
        return {"room": room_id}

    assert install_web_client(app, str(tmp_path)) is True
    return TestClient(app)


def test_root_serves_the_web_app(client):
    r = client.get("/")
    assert r.status_code == 200 and "SPA" in r.text


def test_client_side_routes_fall_back_to_index(client):
    r = client.get("/j/ABC123")
    assert r.status_code == 200 and "SPA" in r.text


def test_real_assets_are_served_and_missing_assets_404(client):
    assert client.get("/assets/app.js").status_code == 200
    assert client.get("/assets/missing.js").status_code == 404


def test_api_routes_win_over_the_web_app(client):
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/rooms/abc").json() == {"room": "abc"}


def test_api_prefix_is_stripped_like_vite_and_vercel_do(client):
    assert client.get("/api/healthz").json() == {"status": "ok"}
    assert client.get("/api/rooms/abc").json() == {"room": "abc"}


def test_nothing_is_mounted_without_a_build(tmp_path):
    app = FastAPI()
    assert install_web_client(app, "") is False
    assert install_web_client(app, str(tmp_path)) is False  # folder without index.html
    assert TestClient(app).get("/").status_code == 404


def test_cache_policy_keeps_index_fresh_and_assets_forever(client):
    # an open tab must notice a new deploy; hashed assets never change
    assert client.get("/").headers["cache-control"] == "no-cache"
    assert client.get("/j/ABC123").headers["cache-control"] == "no-cache"
    assert "immutable" in client.get("/assets/app.js").headers["cache-control"]
