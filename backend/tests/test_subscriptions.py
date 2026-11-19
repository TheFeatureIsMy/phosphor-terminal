"""Manual subscription lifecycle and expiry downgrade."""
from datetime import datetime, timedelta, timezone

from app.models.tenant import Tenant, TenantAuditLog
from app.services.subscriptions import expire_due, get_subscription, set_subscription


def test_subscription_activates_and_expires(session):
    tenant = Tenant(name="sub", slug="sub", plan="free")
    session.add(tenant)
    session.commit()
    set_subscription(
        session, tenant, plan="pro",
        period_end=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=30),
    )
    session.commit()
    assert tenant.plan == "pro"
    assert get_subscription(session, tenant.id).plan == "pro"

    row = get_subscription(session, tenant.id)
    row.current_period_end = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=5)
    session.commit()
    assert expire_due(session) == 1
    session.refresh(tenant)
    assert tenant.plan == "free"
    actions = [r.action for r in session.query(TenantAuditLog).all()]
    assert "subscription.update" in actions
    assert "subscription.expired" in actions


def test_expiry_ignores_future(session):
    tenant = Tenant(name="sub2", slug="sub2", plan="pro")
    session.add(tenant)
    session.commit()
    set_subscription(
        session, tenant, plan="pro",
        period_end=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=30),
    )
    session.commit()
    assert expire_due(session) == 0


def test_grace_period_keeps_plan(session):
    tenant = Tenant(name="grace", slug="grace", plan="pro")
    session.add(tenant)
    session.commit()
    set_subscription(
        session, tenant, plan="pro",
        period_end=datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=1),
    )
    session.commit()
    assert expire_due(session, grace_days=3) == 0
    session.refresh(tenant)
    assert tenant.plan == "pro"


def test_renewal_reminder_sent_once(session, monkeypatch):
    from app.models.tenant import Membership
    from app.models.user import User
    from app.services.email_service import EmailService
    from app.services.subscriptions import send_renewal_reminders

    sent = []
    monkeypatch.setattr(EmailService, "configured", property(lambda self: True))
    monkeypatch.setattr(
        EmailService, "send_renewal_reminder",
        lambda self, **kwargs: sent.append(kwargs) or True,
    )
    tenant = Tenant(name="renew", slug="renew", plan="pro")
    user = User(username="renewowner", email="renew@example.com", hashed_password="x")
    session.add_all([tenant, user])
    session.flush()
    session.add(Membership(user_id=user.id, tenant_id=tenant.id, role="owner"))
    set_subscription(
        session, tenant, plan="pro",
        period_end=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=3),
    )
    session.commit()

    assert send_renewal_reminders(session, days=7) == 1
    assert send_renewal_reminders(session, days=7) == 0
    assert sent and sent[0]["to"] == "renew@example.com"


def test_canceled_subscription_downgrades_after_period(session):
    from app.services.subscriptions import set_subscription

    tenant = Tenant(name="cancel", slug="cancel", plan="pro")
    session.add(tenant)
    session.commit()
    set_subscription(session, tenant, plan="pro")
    session.commit()
    future = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=10)
    set_subscription(
        session, tenant, plan="pro", status="canceled", period_end=future,
    )
    session.commit()
    assert tenant.plan == "pro"
    past = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=1)
    set_subscription(
        session, tenant, plan="pro", status="canceled", period_end=past,
    )
    session.commit()
    assert tenant.plan == "free"


def test_cancel_endpoint_keeps_plan_until_period_end(client, session):
    from app.models.tenant import Tenant
    from app.models.user import User
    from app.services.auth import create_access_token
    from app.services.subscriptions import set_subscription

    tenant = Tenant(name="cancel-api", slug="cancel-api", plan="pro")
    admin = User(
        username="canceladmin", email="canceladmin@example.com",
        hashed_password="x", is_superuser=True,
    )
    session.add_all([tenant, admin])
    session.flush()
    set_subscription(
        session, tenant, plan="pro",
        period_end=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=10),
    )
    session.commit()
    token = create_access_token(
        {"sub": str(admin.id), "tid": str(tenant.id), "role": "owner"}
    )
    response = client.post(
        "/api/admin/tenant-subscription/cancel",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    assert response.json()["status"] == "canceled"
    session.refresh(tenant)
    assert tenant.plan == "pro"
