"""Provider-agnostic billing webhook and public plan catalog."""
from __future__ import annotations

import hashlib
import hmac
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.tenant import BillingEvent, Tenant
from app.services.subscriptions import set_subscription
from app.services.tenant_limits import PLAN_LIMITS, limits_for

router = APIRouter(prefix="/api/v1/billing", tags=["billing"])


@router.get("/plans")
def plans():
    return [
        {"plan": plan, "limits": limits_for(plan)}
        for plan in ("free", "pro", "enterprise")
    ]


def _verify_stripe_signature(body: bytes, header: str) -> bool:
    """Stripe scheme: t=<unix>,v1=<hmac_sha256(secret, t + '.' + body)>."""
    if not settings.billing_stripe_webhook_secret:
        return False
    parts = {}
    for item in header.split(","):
        key, _, value = item.partition("=")
        parts.setdefault(key.strip(), value.strip())
    timestamp, signature = parts.get("t"), parts.get("v1")
    if not timestamp or not signature or not timestamp.isdigit():
        return False
    import time

    if abs(time.time() - int(timestamp)) > 300:
        return False
    expected = hmac.new(
        settings.billing_stripe_webhook_secret.encode(),
        f"{timestamp}.".encode() + body,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def _stripe_status(status: str) -> str:
    if status in ("active", "trialing"):
        return "active"
    if status in ("past_due", "unpaid"):
        return "past_due"
    if status in ("canceled", "incomplete_expired"):
        return "expired" if status == "incomplete_expired" else "canceled"
    return "past_due"


def _normalize(payload: dict) -> dict:
    """Accept either our generic payload or a Stripe event envelope."""
    if "data" not in payload or not isinstance(payload.get("data"), dict):
        return payload
    obj = (payload.get("data") or {}).get("object") or {}
    event_type = str(payload.get("type", ""))
    if event_type.startswith("invoice."):
        details = obj.get("subscription_details") or {}
        metadata = details.get("metadata") or obj.get("metadata") or {}
        period_end = (obj.get("period") or {}).get("end")
        try:
            period_end = obj["lines"]["data"][0]["period"]["end"]
        except (KeyError, IndexError, TypeError):
            pass
        return {
            "tenant_id": metadata.get("tenant_id"),
            "plan": metadata.get("plan", "pro"),
            "status": "active" if event_type == "invoice.paid" else "past_due",
            "current_period_end": period_end,
            "provider": "stripe",
            "external_id": obj.get("subscription"),
            "event_id": payload.get("id"),
            "event_type": event_type,
        }
    metadata = obj.get("metadata") or {}
    price = ""
    try:
        price = obj["items"]["data"][0]["price"]["id"]
    except (KeyError, IndexError, TypeError):
        pass
    plan = metadata.get("plan")
    if not plan:
        if price and price == settings.billing_stripe_price_pro:
            plan = "pro"
        elif price and price == settings.billing_stripe_price_enterprise:
            plan = "enterprise"
        else:
            plan = "free"
    return {
        "tenant_id": metadata.get("tenant_id"),
        "plan": plan,
        "status": _stripe_status(str(obj.get("status", "active"))),
        "current_period_end": obj.get("current_period_end"),
        "provider": "stripe",
        "external_id": obj.get("id"),
        "event_id": payload.get("id"),
        "event_type": payload.get("type"),
    }


def _notify_payment_failed(db: Session, tenant: Tenant, plan: str) -> None:
    from app.models.tenant import Membership
    from app.models.user import User
    from app.services.email_service import EmailService

    service = EmailService()
    if not service.configured:
        return
    emails = (
        db.query(User.email)
        .join(Membership, Membership.user_id == User.id)
        .filter(
            Membership.tenant_id == tenant.id,
            Membership.role.in_(["owner", "admin"]),
        )
        .all()
    )
    for (email,) in emails:
        service.send_payment_failed(to=email, tenant_name=tenant.name, plan=plan)


@router.post("/webhook")
async def webhook(
    request: Request,
    x_billing_signature: str | None = Header(default=None),
    stripe_signature: str | None = Header(default=None, alias="Stripe-Signature"),
    db: Session = Depends(get_db),
):
    if not settings.billing_enabled or not (
        settings.billing_webhook_secret or settings.billing_stripe_webhook_secret
    ):
        raise HTTPException(status_code=503, detail="Billing webhook is disabled")
    body = await request.body()
    if stripe_signature:
        ok = _verify_stripe_signature(body, stripe_signature)
    else:
        expected = hmac.new(
            settings.billing_webhook_secret.encode(), body, hashlib.sha256
        ).hexdigest()
        provided = (x_billing_signature or "").removeprefix("sha256=")
        ok = hmac.compare_digest(expected, provided)
    if not ok:
        raise HTTPException(status_code=401, detail="Invalid billing signature")

    try:
        payload = _normalize(json.loads(body))
        tenant_id = int(payload["tenant_id"])
        plan = str(payload["plan"])
        status = str(payload.get("status", "active"))
        external_id = payload.get("external_id")
        period_raw = payload.get("current_period_end")
    except (KeyError, TypeError, ValueError, json.JSONDecodeError):
        raise HTTPException(status_code=422, detail="Invalid billing payload")
    if plan not in PLAN_LIMITS or status not in (
        "active", "past_due", "canceled", "expired",
    ):
        raise HTTPException(status_code=422, detail="Unknown plan or status")

    tenant = db.get(Tenant, tenant_id)
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    provider = str(payload.get("provider", "manual"))
    event_id = payload.get("event_id")
    if event_id:
        existing = db.query(BillingEvent).filter(
            BillingEvent.provider == provider,
            BillingEvent.event_id == str(event_id),
        ).first()
        if existing is not None:
            return {
                "ok": True, "duplicate": True,
                "tenant_id": tenant.id, "plan": tenant.plan, "status": status,
            }
        db.add(BillingEvent(
            tenant_id=tenant.id, provider=provider,
            event_id=str(event_id), event_type=str(payload.get("event_type", "")),
        ))
    period_end = None
    if period_raw:
        try:
            raw = str(period_raw)
            if raw.isdigit():
                period_end = datetime.fromtimestamp(int(raw), tz=timezone.utc).replace(tzinfo=None)
            else:
                period_end = datetime.fromisoformat(raw.replace("Z", "+00:00"))
                if period_end.tzinfo is not None:
                    period_end = period_end.astimezone(timezone.utc).replace(tzinfo=None)
        except (TypeError, ValueError):
            raise HTTPException(status_code=422, detail="Invalid current_period_end")

    set_subscription(
        db, tenant, plan=plan, status=status, period_end=period_end,
        provider=provider,
        external_id=str(external_id) if external_id else None,
    )
    db.commit()
    if status == "past_due":
        _notify_payment_failed(db, tenant, plan)
    return {"ok": True, "tenant_id": tenant.id, "plan": tenant.plan, "status": status}
