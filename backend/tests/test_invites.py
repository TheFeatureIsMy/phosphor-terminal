"""Invite links create users in the inviter's tenant exactly once."""
from app.config import settings
from app.models.tenant import Membership, Tenant
from app.models.user import User
from app.services.auth import create_access_token


def _setup(session):
    tenant = Tenant(name="inv", slug="inv")
    session.add(tenant)
    session.flush()
    owner = User(username="invowner", email="invowner@example.com",
                 hashed_password="x", is_active=True, is_superuser=False)
    session.add(owner)
    session.flush()
    session.add(Membership(user_id=owner.id, tenant_id=tenant.id, role="owner"))
    session.commit()
    token = create_access_token(
        {"sub": str(owner.id), "tid": str(tenant.id), "role": "owner"}
    )
    return tenant, owner, {"Authorization": f"Bearer {token}"}


def test_invite_accept_flow(client, session, monkeypatch):
    from app.models.tenant import TenantInvite

    monkeypatch.setattr(settings, "auth_required", True)
    tenant, owner, headers = _setup(session)

    created = client.post(
        "/auth/invites",
        json={"email": "invitee@example.com", "role": "trader"},
        headers=headers,
    )
    assert created.status_code == 201, created.text
    token = created.json()["token"]
    row = session.query(TenantInvite).one()
    assert row.token_hash != token

    accepted = client.post("/auth/invites/accept", json={
        "token": token, "username": "invitee", "password": "secret123",
    })
    assert accepted.status_code == 201, accepted.text
    assert accepted.json()["tenant_id"] == tenant.id

    # The new user can log in and belongs to the tenant.
    login = client.post("/auth/login", data={
        "username": "invitee@example.com", "password": "secret123",
    })
    assert login.status_code == 200
    token2 = login.json()["access_token"]
    tenant_info = client.get(
        "/auth/tenant", headers={"Authorization": f"Bearer {token2}"},
    )
    assert tenant_info.status_code == 200
    assert tenant_info.json()["role"] == "trader"

    # One-time use.
    again = client.post("/auth/invites/accept", json={
        "token": token, "username": "invitee2", "password": "secret123",
    })
    assert again.status_code == 400

    listed = client.get("/auth/invites", headers=headers)
    assert listed.status_code == 200
    assert listed.json()[0]["accepted"] is True


def test_invite_email_sent_when_smtp_configured(client, session, monkeypatch):
    monkeypatch.setattr(settings, "auth_required", True)
    monkeypatch.setattr(settings, "smtp_host", "smtp.test")
    monkeypatch.setattr(settings, "smtp_from", "noreply@test")
    monkeypatch.setattr(settings, "public_base_url", "https://app.test")
    _tenant, _owner, headers = _setup(session)

    sent = {}

    class FakeSMTP:
        def __init__(self, host, port, timeout=10):
            sent["host"] = host

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def ehlo(self):
            pass

        def starttls(self):
            pass

        def login(self, user, password):
            pass

        def send_message(self, message):
            sent["to"] = message["To"]
            sent["body"] = message.get_content()

    import smtplib
    monkeypatch.setattr(smtplib, "SMTP", FakeSMTP)

    created = client.post(
        "/auth/invites",
        json={"email": "mail@example.com", "role": "viewer"},
        headers=headers,
    )
    assert created.status_code == 201, created.text
    assert created.json()["email_sent"] is True
    assert sent["host"] == "smtp.test"
    assert sent["to"] == "mail@example.com"
    assert "https://app.test/?invite_token=" in sent["body"]
