"""Login sessions are recorded and revocation invalidates the token."""
from app.config import settings
from app.services.auth import decode_token


def test_login_session_and_revoke(client, monkeypatch):
    monkeypatch.setattr(settings, "auth_required", True)
    r = client.post("/auth/register", json={
        "username": "sessuser", "email": "sess@example.com", "password": "secret123",
    })
    assert r.status_code == 201
    r = client.post("/auth/login", data={
        "username": "sess@example.com", "password": "secret123",
    })
    assert r.status_code == 200
    token = r.json()["access_token"]
    payload = decode_token(token)
    sid = payload["sid"]
    headers = {"Authorization": f"Bearer {token}"}

    sessions = client.get("/auth/sessions", headers=headers)
    assert sessions.status_code == 200
    assert any(s["id"] == sid for s in sessions.json())
    assert client.get("/auth/me", headers=headers).status_code == 200

    revoked = client.post(f"/auth/sessions/{sid}/revoke", headers=headers)
    assert revoked.status_code == 200
    assert client.get("/auth/me", headers=headers).status_code == 401
    assert client.get("/auth/sessions", headers=headers).status_code == 401


def test_logout_revokes_current_session(client, monkeypatch):
    monkeypatch.setattr(settings, "auth_required", True)
    client.post("/auth/register", json={
        "username": "logoutuser", "email": "logout@example.com", "password": "secret123",
    })
    r = client.post("/auth/login", data={
        "username": "logout@example.com", "password": "secret123",
    })
    token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    assert client.post("/auth/logout", headers=headers).status_code == 200
    assert client.get("/auth/me", headers=headers).status_code == 401


def test_expired_session_is_rejected(client, session, monkeypatch):
    from datetime import datetime, timedelta, timezone
    from app.models.tenant import DeviceSession

    monkeypatch.setattr(settings, "auth_required", True)
    client.post("/auth/register", json={
        "username": "expuser", "email": "exp@example.com", "password": "secret123",
    })
    r = client.post("/auth/login", data={
        "username": "exp@example.com", "password": "secret123",
    })
    token = r.json()["access_token"]
    sid = decode_token(token)["sid"]
    row = session.get(DeviceSession, sid)
    row.expires_at = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(minutes=1)
    session.commit()
    assert client.get("/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_cleanup_removes_old_sessions(client, session):
    from datetime import datetime, timedelta, timezone
    from app.models.tenant import DeviceSession, Tenant
    from app.models.user import User

    tenant = Tenant(name="clean", slug="clean")
    session.add(tenant)
    session.flush()
    user = User(username="cleanuser", email="clean@example.com", hashed_password="x",
                is_active=True, is_superuser=True)
    session.add(user)
    session.flush()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    old = now - timedelta(days=60)
    session.add_all([
        DeviceSession(id="old-revoked", user_id=user.id, tenant_id=tenant.id,
                      revoked_at=old, expires_at=now + timedelta(days=30)),
        DeviceSession(id="old-expired", user_id=user.id, tenant_id=tenant.id,
                      expires_at=old),
        DeviceSession(id="active", user_id=user.id, tenant_id=tenant.id,
                      expires_at=now + timedelta(days=30)),
    ])
    session.commit()

    resp = client.post("/api/admin/sessions/cleanup?retention_days=30")
    assert resp.status_code == 200
    assert resp.json()["deleted"] == 2
    remaining = {row.id for row in session.query(DeviceSession).all()}
    assert remaining == {"active"}
