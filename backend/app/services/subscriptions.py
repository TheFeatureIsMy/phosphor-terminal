"""Manual subscription records; no payment provider integration yet."""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.tenant import Tenant, TenantSubscription
from app.services.tenant_audit import record_tenant_audit


def get_subscription(db: Session, tenant_id: int) -> TenantSubscription | None:
    return db.query(TenantSubscription).filter(
        TenantSubscription.tenant_id == tenant_id
    ).first()


def set_subscription(
    db: Session,
    tenant: Tenant,
    *,
    plan: str,
    status: str = "active",
    period_end: datetime | None = None,
    provider: str = "manual",
    external_id: str | None = None,
    actor_user_id: int | None = None,
) -> TenantSubscription:
    row = get_subscription(db, tenant.id)
    if row is None:
        row = TenantSubscription(tenant_id=tenant.id)
        db.add(row)
    row.plan = plan
    row.status = status
    row.provider = provider
    row.external_id = external_id
    row.current_period_end = period_end
    if status == "active":
        tenant.plan = plan
    elif status in ("canceled", "expired"):
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        if period_end is None or period_end <= now:
            tenant.plan = "free"
    record_tenant_audit(
        db, tenant.id, "subscription.update", actor_user_id=actor_user_id,
        detail={"plan": plan, "status": status, "provider": provider},
    )
    return row


def expire_due(
    db: Session, now: datetime | None = None, grace_days: int | None = None,
) -> int:
    from app.config import settings

    now = now or datetime.now(timezone.utc).replace(tzinfo=None)
    grace = grace_days if grace_days is not None else settings.billing_grace_days
    cutoff = now - __import__("datetime").timedelta(days=max(0, grace))
    rows = db.query(TenantSubscription).filter(
        TenantSubscription.status.in_(["active", "past_due", "canceled"]),
        TenantSubscription.current_period_end.isnot(None),
        TenantSubscription.current_period_end < cutoff,
    ).all()
    for row in rows:
        row.status = "expired"
        tenant = db.get(Tenant, row.tenant_id)
        if tenant is not None:
            tenant.plan = "free"
            record_tenant_audit(
                db, tenant.id, "subscription.expired",
                detail={"previous_plan": row.plan},
            )
    db.commit()
    return len(rows)


class SubscriptionExpiryScheduler:
    def __init__(self, interval_hours: int | None = None) -> None:
        import asyncio

        from app.config import settings

        hours = (
            interval_hours if interval_hours is not None
            else settings.subscription_expiry_interval_hours
        )
        self.interval_s = max(0, hours) * 3600
        self.enabled = self.interval_s > 0
        self._task = None
        self._stop = asyncio.Event()

    async def start(self) -> None:
        import asyncio
        import logging

        if not self.enabled or self._task is not None:
            return
        self._task = asyncio.create_task(self._loop(), name="subscription-expiry")
        logging.getLogger(__name__).info("subscription expiry scheduler started")

    async def stop(self) -> None:
        import asyncio

        if self._task is None:
            return
        self._stop.set()
        try:
            await asyncio.wait_for(self._task, timeout=5.0)
        except asyncio.TimeoutError:
            self._task.cancel()
        self._task = None

    async def _loop(self) -> None:
        import asyncio

        from app.database import WorkerSessionLocal

        while not self._stop.is_set():
            db = WorkerSessionLocal()
            try:
                expire_due(db)
                send_renewal_reminders(db)
            except Exception:
                db.rollback()
            finally:
                db.close()
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self.interval_s)
            except asyncio.TimeoutError:
                continue


def send_renewal_reminders(
    db: Session, now: datetime | None = None, days: int | None = None,
) -> int:
    from datetime import timedelta

    from app.config import settings
    from app.models.tenant import Membership, TenantAuditLog
    from app.models.user import User
    from app.services.email_service import EmailService

    now = now or datetime.now(timezone.utc).replace(tzinfo=None)
    window = days if days is not None else settings.billing_renewal_reminder_days
    cutoff = now + timedelta(days=max(0, window))
    rows = db.query(TenantSubscription).filter(
        TenantSubscription.status.in_(["active", "past_due"]),
        TenantSubscription.current_period_end.isnot(None),
        TenantSubscription.current_period_end >= now,
        TenantSubscription.current_period_end <= cutoff,
    ).all()
    service = EmailService()
    sent = 0
    for row in rows:
        tenant = db.get(Tenant, row.tenant_id)
        if tenant is None:
            continue
        recent = db.query(TenantAuditLog).filter(
            TenantAuditLog.tenant_id == tenant.id,
            TenantAuditLog.action == "subscription.renewal_reminder",
            TenantAuditLog.created_at >= now - timedelta(days=7),
        ).first()
        if recent is not None:
            continue
        record_tenant_audit(
            db, tenant.id, "subscription.renewal_reminder",
            detail={"plan": row.plan, "period_end": row.current_period_end.isoformat()},
        )
        if service.configured:
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
                service.send_renewal_reminder(
                    to=email, tenant_name=tenant.name, plan=row.plan,
                    period_end=row.current_period_end.date().isoformat(),
                )
        sent += 1
    db.commit()
    return sent
