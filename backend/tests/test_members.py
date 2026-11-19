"""Tenant member management requires owner/admin and protects the last owner."""
from app.config import settings
from app.models.tenant import Membership, Tenant
from app.models.user import User
from app.services.auth import create_access_token


def _headers(user, tenant_id):
    token = create_access_token(
        {"sub": str(user.id), "tid": str(tenant_id), "role": "owner"}
    )
    return {"Authorization": f"Bearer {token}"}


def _setup(session):
    tenant = Tenant(name="team", slug="team")
    session.add(tenant)
    session.flush()
    owner = User(username="owner", email="owner@example.com", hashed_password="x",
                 is_active=True, is_superuser=False)
    viewer = User(username="viewer", email="viewer@example.com", hashed_password="x",
                  is_active=True, is_superuser=False)
    session.add_all([owner, viewer])
    session.flush()
    session.add_all([
        Membership(user_id=owner.id, tenant_id=tenant.id, role="owner"),
        Membership(user_id=viewer.id, tenant_id=tenant.id, role="viewer"),
    ])
    session.commit()
    return tenant, owner, viewer


def test_owner_can_manage_members(client, session, monkeypatch):
    monkeypatch.setattr(settings, "auth_required", True)
    tenant, owner, viewer = _setup(session)
    headers = _headers(owner, tenant.id)

    created = client.post(
        "/auth/members",
        json={"username": "trader1", "email": "t1@example.com",
              "password": "secret123", "role": "trader"},
        headers=headers,
    )
    assert created.status_code == 201, created.text
    user_id = created.json()["user_id"]

    listing = client.get("/auth/members", headers=headers)
    assert listing.status_code == 200
    assert {m["username"] for m in listing.json()} == {"owner", "viewer", "trader1"}

    patched = client.patch(
        f"/auth/members/{user_id}", json={"role": "admin"}, headers=headers,
    )
    assert patched.status_code == 200
    assert patched.json()["role"] == "admin"

    removed = client.delete(f"/auth/members/{user_id}", headers=headers)
    assert removed.status_code == 204

    # The last owner cannot be removed or demoted.
    assert client.delete(
        f"/auth/members/{owner.id}", headers=headers,
    ).status_code == 409
    assert client.patch(
        f"/auth/members/{owner.id}", json={"role": "viewer"}, headers=headers,
    ).status_code == 409

    # A viewer is not a manager.
    assert client.post(
        "/auth/members",
        json={"username": "x", "email": "x@example.com", "password": "secret123"},
        headers=_headers(viewer, tenant.id),
    ).status_code == 403
