"""Auth middleware regression tests (P0 security baseline)."""
from __future__ import annotations

import pytest

from app.config import settings
from app.services.auth import create_access_token


@pytest.fixture
def auth_on(monkeypatch):
    monkeypatch.setattr(settings, "auth_required", True)
    yield
    # monkeypatch restores the attribute automatically


def _token(sub: str = "1") -> str:
    return create_access_token({"sub": sub})


class TestAuthMiddleware:
    def test_protected_route_rejects_anonymous(self, client, auth_on):
        resp = client.post("/api/trading/start-paper", json={})
        assert resp.status_code == 401
        assert resp.json()["reason_codes"] == ["authentication_required"]
        assert resp.headers["www-authenticate"] == "Bearer"

    def test_health_stays_public(self, client, auth_on):
        resp = client.get("/health")
        assert resp.status_code == 200

    def test_auth_login_stays_public(self, client, auth_on):
        # No credentials supplied: the auth router answers, the middleware does not.
        resp = client.post("/auth/login", data={"username": "x", "password": "y"})
        assert resp.json().get("reason_codes") != ["authentication_required"]

    def test_valid_token_passes(self, client, auth_on):
        resp = client.get(
            "/api/commands", headers={"Authorization": f"Bearer {_token()}"}
        )
        assert resp.status_code != 401

    def test_invalid_token_rejected(self, client, auth_on):
        resp = client.get(
            "/api/commands", headers={"Authorization": "Bearer not-a-jwt"}
        )
        assert resp.status_code == 401

    def test_refresh_token_cannot_call_api(self, client, auth_on):
        from app.services.auth import create_refresh_token

        resp = client.get(
            "/api/commands",
            headers={"Authorization": f"Bearer {create_refresh_token({'sub': '1'})}"},
        )
        assert resp.status_code == 401

    def test_cors_preflight_not_blocked(self, client, auth_on):
        resp = client.options(
            "/api/commands",
            headers={
                "Origin": "http://localhost:5173",
                "Access-Control-Request-Method": "GET",
            },
        )
        assert resp.status_code != 401

    def test_auth_disabled_allows_anonymous(self, client, monkeypatch):
        monkeypatch.setattr(settings, "auth_required", False)
        resp = client.get("/api/commands")
        assert resp.status_code != 401


class TestTrustedHosts:
    def test_untrusted_host_is_rejected(self):
        from fastapi.testclient import TestClient

        from app.main import app

        with TestClient(app, base_url="http://evil.example") as client:
            resp = client.get("/health")
        assert resp.status_code == 400
