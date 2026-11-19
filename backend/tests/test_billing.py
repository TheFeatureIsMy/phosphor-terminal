"""Billing webhook signature and plan sync."""
import hashlib
import hmac
import json

import pytest

from app.config import settings
from app.models.tenant import Tenant


def _post(client, payload, secret="billing-secret"):
    body = json.dumps(payload).encode()
    signature = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return client.post(
        "/api/v1/billing/webhook", content=body,
        headers={"Content-Type": "application/json", "X-Billing-Signature": signature},
    )


@pytest.fixture
def billing(monkeypatch):
    monkeypatch.setattr(settings, "billing_enabled", True)
    monkeypatch.setattr(settings, "billing_webhook_secret", "billing-secret")


def test_webhook_updates_subscription(client, session, billing):
    tenant = Tenant(name="bill", slug="bill", plan="free")
    session.add(tenant)
    session.commit()
    response = _post(client, {
        "tenant_id": tenant.id, "plan": "pro", "status": "active",
        "current_period_end": "2026-12-31T00:00:00Z", "external_id": "sub_1",
    })
    assert response.status_code == 200
    session.refresh(tenant)
    assert tenant.plan == "pro"


def test_webhook_rejects_bad_signature(client, billing):
    body = b'{"tenant_id":1,"plan":"pro"}'
    response = client.post(
        "/api/v1/billing/webhook", content=body,
        headers={"X-Billing-Signature": "bad"},
    )
    assert response.status_code == 401


def test_webhook_disabled_without_secret(client, monkeypatch):
    monkeypatch.setattr(settings, "billing_enabled", False)
    assert client.post("/api/v1/billing/webhook", content=b"{}").status_code == 503


def test_plans_catalog(client):
    response = client.get("/api/v1/billing/plans")
    assert response.status_code == 200
    assert {row["plan"] for row in response.json()} == {"free", "pro", "enterprise"}


def test_webhook_is_idempotent_by_event_id(client, session, billing):
    tenant = Tenant(name="bill2", slug="bill2", plan="free")
    session.add(tenant)
    session.commit()
    payload = {
        "tenant_id": tenant.id, "plan": "pro", "status": "active",
        "event_id": "evt_1", "provider": "stripe",
    }
    assert _post(client, payload).json().get("duplicate") is None
    second = _post(client, {**payload, "plan": "enterprise"})
    assert second.status_code == 200
    assert second.json()["duplicate"] is True
    session.refresh(tenant)
    assert tenant.plan == "pro"


def test_stripe_event_maps_plan_and_status(client, session, billing, monkeypatch):
    monkeypatch.setattr(settings, "billing_stripe_price_pro", "price_pro")
    tenant = Tenant(name="stripe", slug="stripe", plan="free")
    session.add(tenant)
    session.commit()
    payload = {
        "id": "evt_stripe_1",
        "type": "customer.subscription.updated",
        "data": {"object": {
            "id": "sub_1", "status": "trialing",
            "current_period_end": 1798761600,
            "metadata": {"tenant_id": str(tenant.id)},
            "items": {"data": [{"price": {"id": "price_pro"}}]},
        }},
    }
    response = _post(client, payload)
    assert response.status_code == 200, response.text
    session.refresh(tenant)
    assert tenant.plan == "pro"


def _stripe_headers(body: bytes, secret: str, timestamp: int | None = None):
    import time

    ts = timestamp or int(time.time())
    sig = hmac.new(secret.encode(), f"{ts}.".encode() + body, hashlib.sha256).hexdigest()
    return {"Stripe-Signature": f"t={ts},v1={sig}"}


def test_stripe_signature_verification(client, session, monkeypatch):
    import time

    monkeypatch.setattr(settings, "billing_enabled", True)
    monkeypatch.setattr(settings, "billing_webhook_secret", "")
    monkeypatch.setattr(settings, "billing_stripe_webhook_secret", "whsec_test")
    tenant = Tenant(name="stripe-sig", slug="stripe-sig", plan="free")
    session.add(tenant)
    session.commit()
    payload = {
        "id": "evt_sig", "type": "customer.subscription.updated",
        "data": {"object": {
            "id": "sub_sig", "status": "active",
            "metadata": {"tenant_id": str(tenant.id), "plan": "pro"},
        }},
    }
    body = json.dumps(payload).encode()
    ok = client.post("/api/v1/billing/webhook", content=body, headers=_stripe_headers(body, "whsec_test"))
    assert ok.status_code == 200
    session.refresh(tenant)
    assert tenant.plan == "pro"

    stale = _stripe_headers(body, "whsec_test", int(time.time()) - 1000)
    assert client.post("/api/v1/billing/webhook", content=body, headers=stale).status_code == 401


def test_invoice_payment_failed_keeps_plan_but_marks_past_due(client, session, billing):
    from app.services.subscriptions import set_subscription

    tenant = Tenant(name="invoice", slug="invoice", plan="pro")
    session.add(tenant)
    session.commit()
    set_subscription(session, tenant, plan="pro")
    session.commit()
    payload = {
        "id": "evt_invoice_1", "type": "invoice.payment_failed",
        "data": {"object": {
            "id": "in_1", "subscription": "sub_1",
            "subscription_details": {"metadata": {"tenant_id": str(tenant.id), "plan": "pro"}},
        }},
    }
    assert _post(client, payload).status_code == 200
    session.refresh(tenant)
    assert tenant.plan == "pro"
    from app.services.subscriptions import get_subscription
    assert get_subscription(session, tenant.id).status == "past_due"


def test_payment_failed_emails_owner(client, session, billing, monkeypatch):
    from app.models.tenant import Membership
    from app.models.user import User
    from app.services.email_service import EmailService
    from app.services.subscriptions import set_subscription

    sent = []
    monkeypatch.setattr(EmailService, "configured", property(lambda self: True))
    monkeypatch.setattr(
        EmailService, "send_payment_failed",
        lambda self, **kwargs: sent.append(kwargs) or True,
    )
    tenant = Tenant(name="dunning", slug="dunning", plan="pro")
    user = User(username="dun", email="dun@example.com", hashed_password="x")
    session.add_all([tenant, user])
    session.flush()
    session.add(Membership(user_id=user.id, tenant_id=tenant.id, role="owner"))
    set_subscription(session, tenant, plan="pro")
    session.commit()
    payload = {
        "id": "evt_dun", "type": "invoice.payment_failed",
        "data": {"object": {
            "subscription_details": {"metadata": {"tenant_id": str(tenant.id), "plan": "pro"}},
        }},
    }
    assert _post(client, payload).status_code == 200
    assert sent and sent[0]["to"] == "dun@example.com"
