"""Plan limits reject over-quota member/strategy creation."""
import pytest
from fastapi import HTTPException

from app.models.tenant import Tenant
from app.services.auth import create_access_token
from app.services.tenant_limits import enforce_member_limit, enforce_strategy_limit


def test_member_limit():
    tenant = Tenant(name="lim", slug="lim", plan="free")
    with pytest.raises(HTTPException) as exc:
        enforce_member_limit(None, tenant, 5)
    assert exc.value.status_code == 409
    enforce_member_limit(None, tenant, 4)


def test_strategy_limit():
    tenant = Tenant(name="lim2", slug="lim2", plan="free")
    with pytest.raises(HTTPException) as exc:
        enforce_strategy_limit(None, tenant, 20)
    assert exc.value.status_code == 409
    enforce_strategy_limit(None, tenant, 19)


def test_admin_can_change_plan(client, session):
    tenant = Tenant(name="plan", slug="plan", plan="free")
    session.add(tenant)
    session.commit()
    token = create_access_token(
        {"sub": "1", "tid": str(tenant.id), "role": "owner"}
    )
    headers = {"Authorization": f"Bearer {token}"}
    assert client.get("/api/admin/tenant-plan", headers=headers).json()["plan"] == "free"
    resp = client.put("/api/admin/tenant-plan", json={"plan": "pro"}, headers=headers)
    assert resp.status_code == 200
    assert resp.json()["plan"] == "pro"
    assert resp.json()["limits"]["members"] == 25


def test_plan_change_is_audited(client, session):
    from app.models.tenant import Membership
    from app.models.user import User

    user = User(username="auditor", email="auditor@example.com", hashed_password="x")
    tenant = Tenant(name="audit", slug="audit", plan="free")
    session.add_all([user, tenant])
    session.flush()
    session.add(Membership(user_id=user.id, tenant_id=tenant.id, role="owner"))
    session.commit()
    token = create_access_token({"sub": str(user.id), "tid": str(tenant.id), "role": "owner"})
    headers = {"Authorization": f"Bearer {token}"}
    assert client.put("/api/admin/tenant-plan", json={"plan": "pro"}, headers=headers).status_code == 200
    rows = client.get("/api/admin/tenant-audit", headers=headers).json()
    assert rows and rows[0]["action"] == "plan.update"
    assert rows[0]["detail"] == {"plan": "pro"}


def test_audit_filter_and_export(client, session):
    from app.models.tenant import Membership
    from app.models.user import User

    user = User(username="exporter", email="exporter@example.com", hashed_password="x")
    tenant = Tenant(name="export", slug="export", plan="free")
    session.add_all([user, tenant])
    session.flush()
    session.add(Membership(user_id=user.id, tenant_id=tenant.id, role="owner"))
    session.commit()
    token = create_access_token({"sub": str(user.id), "tid": str(tenant.id), "role": "owner"})
    headers = {"Authorization": f"Bearer {token}"}
    client.put("/api/admin/tenant-plan", json={"plan": "pro"}, headers=headers)
    client.put("/api/admin/tenant-plan", json={"plan": "enterprise"}, headers=headers)

    page = client.get("/api/admin/tenant-audit?action=plan.update&limit=1&offset=1", headers=headers)
    assert page.status_code == 200
    assert len(page.json()) == 1

    exported = client.get("/api/admin/tenant-audit/export?action=plan.update", headers=headers)
    assert exported.status_code == 200
    assert "text/csv" in exported.headers["content-type"]
    assert "plan.update" in exported.text
    assert "attachment" in exported.headers["content-disposition"]
