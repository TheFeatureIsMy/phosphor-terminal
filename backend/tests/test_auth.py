"""Tests for auth endpoints: register, login, refresh, me, settings."""

from fastapi.testclient import TestClient


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _register(client: TestClient, username="testuser", email="test@example.com", password="secret123"):
    return client.post("/auth/register", json={
        "username": username,
        "email": email,
        "password": password,
    })


def _login(client: TestClient, username="testuser", password="secret123"):
    return client.post("/auth/login", data={
        "username": username,
        "password": password,
    })


def _auth_header(access_token: str) -> dict:
    return {"Authorization": f"Bearer {access_token}"}


# ---------------------------------------------------------------------------
# POST /auth/register
# ---------------------------------------------------------------------------

class TestRegister:
    def test_register_success(self, client: TestClient):
        resp = _register(client)
        assert resp.status_code == 201
        body = resp.json()
        assert body["username"] == "testuser"
        assert body["email"] == "test@example.com"
        assert body["is_active"] is True
        assert "id" in body

    def test_register_duplicate_username(self, client: TestClient):
        _register(client)
        resp = _register(client, email="other@example.com")  # same username
        assert resp.status_code == 400
        assert "already taken" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# POST /auth/login
# ---------------------------------------------------------------------------

class TestLogin:
    def test_login_success(self, client: TestClient):
        _register(client)
        resp = _login(client)
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body
        assert "refresh_token" in body
        assert body["token_type"] == "bearer"

    def test_login_wrong_password(self, client: TestClient):
        _register(client)
        resp = _login(client, password="wrongpassword")
        assert resp.status_code == 401
        assert "Invalid credentials" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# POST /auth/refresh
# ---------------------------------------------------------------------------

class TestRefreshToken:
    def test_refresh_valid(self, client: TestClient):
        _register(client)
        tokens = _login(client).json()
        resp = client.post("/auth/refresh", json={
            "refresh_token": tokens["refresh_token"],
        })
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body
        assert "refresh_token" in body

    def test_refresh_invalid_token(self, client: TestClient):
        resp = client.post("/auth/refresh", json={
            "refresh_token": "not.a.valid.token",
        })
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# GET /auth/me
# ---------------------------------------------------------------------------

class TestGetMe:
    def test_me_authenticated(self, client: TestClient):
        _register(client)
        tokens = _login(client).json()
        resp = client.get("/auth/me", headers=_auth_header(tokens["access_token"]))
        assert resp.status_code == 200
        body = resp.json()
        assert body["username"] == "testuser"
        assert body["email"] == "test@example.com"

    def test_me_unauthenticated(self, client: TestClient):
        resp = client.get("/auth/me")
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# GET /auth/settings
# ---------------------------------------------------------------------------

class TestGetSettings:
    def test_get_settings(self, client: TestClient):
        _register(client)
        tokens = _login(client).json()
        resp = client.get("/auth/settings", headers=_auth_header(tokens["access_token"]))
        assert resp.status_code == 200
        body = resp.json()
        assert body["theme"] == "dark"
        assert body["language"] == "zh-CN"
        assert body["notifications_enabled"] is True
        assert body["default_exchange"] == "binance"


# ---------------------------------------------------------------------------
# PUT /auth/settings
# ---------------------------------------------------------------------------

class TestUpdateSettings:
    def test_update_settings(self, client: TestClient):
        _register(client)
        tokens = _login(client).json()
        headers = _auth_header(tokens["access_token"])

        resp = client.put("/auth/settings", headers=headers, json={
            "theme": "light",
            "language": "en",
            "risk_tolerance": "high",
        })
        assert resp.status_code == 200
        body = resp.json()
        assert body["theme"] == "light"
        assert body["language"] == "en"
        assert body["risk_tolerance"] == "high"
        # Unchanged fields remain default
        assert body["default_exchange"] == "binance"
