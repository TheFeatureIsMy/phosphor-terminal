"""Admin/risk endpoints require a superuser once auth is enabled."""
from __future__ import annotations

import uuid

import pytest

from app.config import settings
from app.models.user import User
from app.services.auth import create_access_token


@pytest.fixture
def auth_on(monkeypatch):
    monkeypatch.setattr(settings, "auth_required", True)


def _make_user(session, *, is_superuser: bool) -> User:
    suffix = uuid.uuid4().hex[:8]
    user = User(
        username=f"user-{suffix}",
        email=f"{suffix}@example.com",
        hashed_password="not-used",
        is_active=True,
        is_superuser=is_superuser,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def _headers(user: User) -> dict[str, str]:
    token = create_access_token({"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


class TestAdminRbac:
    def test_admin_providers_rejects_regular_user(self, client, session, auth_on):
        user = _make_user(session, is_superuser=False)
        resp = client.get("/api/admin/providers", headers=_headers(user))
        assert resp.status_code == 403

    def test_admin_providers_allows_superuser(self, client, session, auth_on):
        user = _make_user(session, is_superuser=True)
        resp = client.get("/api/admin/providers", headers=_headers(user))
        assert resp.status_code == 200

    def test_risk_rules_update_rejects_regular_user(self, client, session, auth_on):
        user = _make_user(session, is_superuser=False)
        resp = client.put(
            "/api/risk/rules",
            json={"daily_loss_limit": 3.0},
            headers=_headers(user),
        )
        assert resp.status_code == 403


class TestExecutionIsolationGate:
    def test_execution_routes_reject_regular_user(self, client, session, auth_on):
        user = _make_user(session, is_superuser=False)
        assert client.get("/api/execution/orders", headers=_headers(user)).status_code == 403
        assert client.get("/api/orders", headers=_headers(user)).status_code == 403

    def test_execution_routes_allow_platform_admin(self, client, session, auth_on, monkeypatch):
        from unittest.mock import AsyncMock

        monkeypatch.setattr(
            "app.services.freqtrade_client.FreqtradeClient.get_status",
            AsyncMock(return_value={"error": "offline"}),
        )
        user = _make_user(session, is_superuser=True)
        resp = client.get("/api/execution/orders", headers=_headers(user))
        assert resp.status_code == 200
        assert resp.json()["state"] == "data_source_unavailable"


def test_provider_list_is_tenant_scoped(client, session, auth_on):
    from app.models.provider_config import ProviderConfig
    from app.models.tenant import Membership, Tenant

    tenant_a = Tenant(name="prov-a", slug="prov-a")
    tenant_b = Tenant(name="prov-b", slug="prov-b")
    session.add_all([tenant_a, tenant_b])
    session.flush()

    admin = _make_user(session, is_superuser=True)
    session.add(Membership(user_id=admin.id, tenant_id=tenant_a.id, role="owner"))
    session.commit()

    session.add_all([
        ProviderConfig(
            tenant_id=tenant_a.id, category="cex", provider_name="binance",
            config={}, enabled=True, is_active=False, priority=0,
            status="unknown", credential_status="missing",
        ),
        ProviderConfig(
            tenant_id=tenant_b.id, category="cex", provider_name="okx",
            config={}, enabled=True, is_active=False, priority=0,
            status="unknown", credential_status="missing",
        ),
    ])
    session.commit()

    token = create_access_token(
        {"sub": str(admin.id), "tid": str(tenant_a.id), "role": "owner"}
    )
    resp = client.get(
        "/api/admin/providers",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    names = {item["provider_name"] for item in resp.json()}
    assert names == {"binance"}
