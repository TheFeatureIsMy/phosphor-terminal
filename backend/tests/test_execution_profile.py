"""Tenant execution profile gates and routes execution APIs."""
from app.config import settings
from app.models.tenant import Tenant
from app.models.user import User
from app.services.auth import create_access_token


def _headers(user, tenant_id):
    token = create_access_token(
        {"sub": str(user.id), "tid": str(tenant_id), "role": "owner"}
    )
    return {"Authorization": f"Bearer {token}"}


def test_dedicated_profile_routes_tenant_execution(client, session, monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "auth_required", True)
    monkeypatch.setattr(settings, "tenant_data_root", str(tmp_path))
    tenant = Tenant(name="exec-t", slug="exec-t")
    session.add(tenant)
    session.flush()
    admin = User(username="execadmin", email="ea@example.com", hashed_password="x",
                 is_active=True, is_superuser=True)
    user = User(username="execuser", email="eu@example.com", hashed_password="x",
                is_active=True, is_superuser=False)
    session.add_all([admin, user])
    session.commit()

    admin_headers = _headers(admin, tenant.id)
    user_headers = _headers(user, tenant.id)

    # No profile: tenant execution is closed and health is unconfigured.
    assert client.get("/api/execution/orders", headers=user_headers).status_code == 403
    health = client.get("/api/admin/execution-profile/health", headers=admin_headers)
    assert health.status_code == 200
    assert health.json()["configured"] is False

    plan = client.get("/api/admin/execution-profile/plan", headers=admin_headers)
    assert plan.status_code == 200
    assert plan.json()["container_name"] == f"alphaloop-ft-{tenant.id}"
    assert plan.json()["data_dir"] == f"/data/tenants/{tenant.id}"
    assert plan.json()["configured"] is False

    resp = client.put(
        "/api/admin/execution-profile",
        json={
            "mode": "dedicated",
            "freqtrade_url": "http://127.0.0.1:1",
            "api_username": "tenant-ft",
            "api_password": "tenant-secret",
            "exchange_key": "ex-key",
            "exchange_secret": "ex-secret",
            "enabled": True,
            "max_open_trades": 2,
        },
        headers=admin_headers,
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["api_username"] == "tenant-ft"
    assert body["has_credentials"] is True
    assert body["has_exchange_credentials"] is True
    assert "api_password" not in body
    assert "exchange_secret" not in body

    # Routed to the (unreachable) dedicated runtime, not the shared one.
    resp = client.get("/api/execution/orders", headers=user_headers)
    assert resp.status_code == 200
    assert resp.json()["state"] == "data_source_unavailable"

    health = client.get("/api/admin/execution-profile/health", headers=admin_headers)
    assert health.status_code == 200
    assert health.json()["configured"] is True
    assert health.json()["reachable"] is False
    assert health.json()["runtime_status"] == "unreachable"

    profile = client.get("/api/admin/execution-profile", headers=admin_headers).json()
    assert profile["runtime_status"] == "unreachable"
    assert profile["last_health_at"] is not None

    resp = client.put(
        "/api/admin/execution-profile",
        json={"mode": "dedicated", "freqtrade_url": "http://127.0.0.1:1", "enabled": False},
        headers=admin_headers,
    )
    assert resp.status_code == 200
    assert client.get("/api/execution/orders", headers=user_headers).status_code == 403


    dsl = {
        "schema_version": "2.5", "timeframe": "1h", "symbols": ["BTC/USDT"],
        "entry": {"logic": "AND", "rules": []}, "exit": {"logic": "OR", "rules": []},
        "filters": [], "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
        "risk": {"stoploss": -0.05, "max_open_trades": 5}, "metadata": {},
    }
    rendered = client.post(
        "/api/admin/execution-profile/render-config",
        json={"dsl": dsl, "budget": 10000, "dry_run": True},
        headers=admin_headers,
    )
    assert rendered.status_code == 200, rendered.text
    config = rendered.json()
    assert config["exchange"]["key"] == "ex-key"
    assert config["exchange"]["secret"] == "ex-secret"
    assert config["dry_run"] is True
    assert config["max_open_trades"] == 2

    written = client.post(
        "/api/admin/execution-profile/write-config",
        json={"dsl": dsl, "budget": 10000, "dry_run": True},
        headers=admin_headers,
    )
    assert written.status_code == 200, written.text
    config_path = tmp_path / str(tenant.id) / "config.json"
    assert written.json()["path"] == str(config_path)
    assert config_path.exists()
    assert oct(config_path.stat().st_mode & 0o777) == "0o600"
    assert "ex-key" in config_path.read_text()

    first = client.post("/api/admin/execution-profile/rotate-credentials", headers=admin_headers)
    second = client.post("/api/admin/execution-profile/rotate-credentials", headers=admin_headers)
    assert first.status_code == 200 and second.status_code == 200
    assert first.json()["api_password"] != second.json()["api_password"]
    assert len(second.json()["api_password"]) >= 20


def test_config_and_rotation_are_audited(client, session, monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "auth_required", True)
    monkeypatch.setattr(settings, "tenant_data_root", str(tmp_path))
    tenant = Tenant(name="audit-exec", slug="audit-exec")
    session.add(tenant)
    session.flush()
    admin = User(username="auditadmin", email="aa@example.com", hashed_password="x",
                 is_active=True, is_superuser=True)
    session.add(admin)
    session.commit()
    headers = _headers(admin, tenant.id)
    client.put(
        "/api/admin/execution-profile",
        json={"mode": "disabled", "freqtrade_url": None, "enabled": False,
              "api_username": None, "api_password": None,
              "exchange_key": None, "exchange_secret": None, "max_open_trades": 2},
        headers=headers,
    )
    rotated = client.post("/api/admin/execution-profile/rotate-credentials", headers=headers)
    assert rotated.status_code == 200
    session.expire_all()
    from app.models.tenant import TenantAuditLog
    actions = [row.action for row in session.query(TenantAuditLog).all()]
    assert "credentials.rotate" in actions
