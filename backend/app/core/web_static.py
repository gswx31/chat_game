"""Serve the built web client (web/dist) from the API server itself.

One address then serves both the mobile app's API and the browser game, with no
CORS and no second hosting account.

The web client calls the API under ``/api/...`` (Vite's dev proxy and Vercel strip that
prefix; nothing does when the browser talks straight to this server), so a tiny ASGI
middleware strips it here.
"""

from __future__ import annotations

import logging
from pathlib import Path

from fastapi import FastAPI
from starlette.exceptions import HTTPException
from starlette.staticfiles import StaticFiles
from starlette.types import ASGIApp, Receive, Scope, Send

log = logging.getLogger(__name__)


class StripApiPrefix:
    """Rewrite ``/api/x`` -> ``/x`` (HTTP and WebSocket)."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] in ("http", "websocket"):
            path: str = scope["path"]
            if path == "/api" or path.startswith("/api/"):
                raw: bytes = scope.get("raw_path") or path.encode()
                scope = {
                    **scope,
                    "path": path[4:] or "/",
                    "raw_path": raw[4:] or b"/",
                }
        await self.app(scope, receive, send)


class SPAStaticFiles(StaticFiles):
    """Static files, but an unknown *page* path (``/j/ABC123``) gets index.html so the
    client-side router can handle it. A missing *file* (``/assets/x.js``) stays a 404."""

    async def get_response(self, path: str, scope: Scope):  # type: ignore[override]
        try:
            response = await super().get_response(path, scope)
        except HTTPException as exc:
            last_segment = path.rsplit("/", 1)[-1]
            if exc.status_code == 404 and "." not in last_segment:
                response = await super().get_response("index.html", scope)
                path = "index.html"
            else:
                raise
        # Without an explicit policy browsers cache index.html heuristically and an open tab or a
        # typed URL keeps running an old build. Hashed assets, on the other hand, never change.
        if path.replace("\\", "/").startswith("assets/"):  # os-native separators on Windows
            response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        else:
            response.headers["Cache-Control"] = "no-cache"
        return response


def install_web_client(app: FastAPI, dist_dir: str) -> bool:
    """Mount the web client if ``dist_dir`` holds a build. Returns whether it did."""
    if not dist_dir:
        return False
    root = Path(dist_dir)
    if not (root / "index.html").is_file():
        log.warning("WEB_DIST_DIR=%s has no index.html; serving the API only", dist_dir)
        return False
    app.add_middleware(StripApiPrefix)
    app.mount("/", SPAStaticFiles(directory=root, html=True), name="web")
    log.info("serving web client from %s", root)
    return True
