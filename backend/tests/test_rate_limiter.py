"""RateLimitMiddleware behaviour (config-driven, bounded memory)."""
import time

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.middleware.rate_limiter import RateLimitMiddleware


def _app(limit: int) -> FastAPI:
    app = FastAPI()
    app.add_middleware(RateLimitMiddleware, requests_per_minute=limit, burst_size=1)

    @app.get("/ping")
    def ping():
        return {"ok": True}

    @app.get("/health")
    def health():
        return {"ok": True}

    return app


def test_requests_over_limit_get_429():
    with TestClient(_app(2)) as client:
        assert client.get("/ping").status_code == 200
        assert client.get("/ping").status_code == 200
        resp = client.get("/ping")
        assert resp.status_code == 429
        assert resp.headers["retry-after"] == "60"


def test_health_is_never_limited():
    with TestClient(_app(1)) as client:
        assert client.get("/health").status_code == 200
        assert client.get("/health").status_code == 200


def test_expired_entries_are_purged(monkeypatch):
    import asyncio

    from starlette.responses import JSONResponse

    middleware = RateLimitMiddleware(app=None, requests_per_minute=1)

    class _Request:
        class url:
            path = "/ping"

        class client:
            host = "1.2.3.4"

    async def call_next(_request):
        return JSONResponse({"ok": True})

    assert asyncio.run(middleware.dispatch(_Request(), call_next)).status_code == 200
    assert "1.2.3.4" in middleware.requests

    real_time = time.time
    monkeypatch.setattr(
        "app.middleware.rate_limiter.time.time",
        lambda: real_time() + 61,
    )
    assert asyncio.run(middleware.dispatch(_Request(), call_next)).status_code == 200
    assert all(len(v) <= 1 for v in middleware.requests.values())
