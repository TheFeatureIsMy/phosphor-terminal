"""Command queue stats are tenant-scoped; platform scope is superuser-only."""
import uuid

from app.config import settings
from app.domain.command import CommandBusCommand
from app.models.tenant import Tenant
from app.models.user import User
from app.services.auth import create_access_token


def _cmd(tenant_id, key, status="pending"):
    return CommandBusCommand(
        tenant_id=tenant_id, command_type="test", aggregate_type="test",
        payload={}, idempotency_key=key, requested_by="test", status=status,
    )


def test_command_queue_is_tenant_scoped(client, session, monkeypatch):
    monkeypatch.setattr(settings, "auth_required", True)
    t1 = Tenant(name="q1", slug="q1")
    t2 = Tenant(name="q2", slug="q2")
    session.add_all([t1, t2])
    session.flush()
    user = User(username="quser", email="q@example.com", hashed_password="x",
                is_active=True, is_superuser=False)
    admin = User(username="qadmin", email="qa@example.com", hashed_password="x",
                 is_active=True, is_superuser=True)
    session.add_all([user, admin])
    session.flush()
    session.add_all([_cmd(t1.id, "q1"), _cmd(t2.id, "q2"), _cmd(t2.id, "q3")])
    session.commit()

    token = create_access_token({"sub": str(user.id), "tid": str(t1.id), "role": "owner"})
    resp = client.get("/api/system/command-queue", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["scope"] == "tenant"
    assert body["counts"] == {"pending": 1}

    admin_token = create_access_token(
        {"sub": str(admin.id), "tid": str(t1.id), "role": "owner"}
    )
    resp = client.get(
        "/api/system/command-queue?scope=platform",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["counts"] == {"pending": 3}

    # A normal tenant cannot escalate to platform scope.
    resp = client.get(
        "/api/system/command-queue?scope=platform",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["scope"] == "tenant"
    assert resp.json()["counts"] == {"pending": 1}
