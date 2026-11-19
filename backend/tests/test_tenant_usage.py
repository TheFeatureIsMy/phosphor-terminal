"""Tenant usage vs plan limits."""
from app.domain.strategy import StrategyV2
from app.models.tenant import Membership, Tenant, TenantAuditLog
from app.models.user import User
from app.services.auth import create_access_token


def _user(session, name, role, tenant):
    user = User(username=name, email=f"{name}@example.com", hashed_password="x")
    session.add(user)
    session.flush()
    session.add(Membership(user_id=user.id, tenant_id=tenant.id, role=role))
    session.commit()
    token = create_access_token({"sub": str(user.id), "tid": str(tenant.id), "role": role})
    return {"Authorization": f"Bearer {token}"}


def test_usage_counts(client, session):
    tenant = Tenant(name="usage", slug="usage", plan="pro")
    session.add(tenant)
    session.flush()
    headers = _user(session, "usageowner", "owner", tenant)
    session.add(StrategyV2(name="s1", strategy_type="rule_dsl", source_type="manual", tenant_id=tenant.id))
    session.add(TenantAuditLog(tenant_id=tenant.id, action="x"))
    session.commit()

    response = client.get("/api/admin/tenant-usage", headers=headers)
    assert response.status_code == 200
    body = response.json()
    assert body["plan"] == "pro"
    assert body["limits"]["members"] == 25
    assert body["usage"]["members"] == 1
    assert body["usage"]["strategies"] == 1
    assert body["usage"]["audit_logs"] == 1


def test_usage_requires_manager(client, session):
    tenant = Tenant(name="usage2", slug="usage2")
    session.add(tenant)
    session.flush()
    headers = _user(session, "usageviewer", "viewer", tenant)
    assert client.get("/api/admin/tenant-usage", headers=headers).status_code == 403


def test_quota_warnings_threshold():
    from app.services.tenant_limits import quota_warnings

    assert quota_warnings("free", {"members": 2, "strategies": 10}) == []
    warnings = quota_warnings("free", {"members": 4, "strategies": 20})
    assert [w["resource"] for w in warnings] == ["members", "strategies"]


def test_quota_warning_ratio_override():
    from app.services.tenant_limits import quota_warnings

    assert quota_warnings("free", {"members": 3, "strategies": 0}, ratio=0.9) == []
    assert quota_warnings("free", {"members": 3, "strategies": 0}, ratio=0.5)
