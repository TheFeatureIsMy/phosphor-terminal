"""Periodic in-app quota warnings, recorded once per day per resource."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.domain.strategy import StrategyV2
from app.models.tenant import Membership, Tenant, TenantAuditLog
from app.models.user import User
from app.services.tenant_audit import record_tenant_audit
from app.services.tenant_limits import quota_warnings

logger = logging.getLogger(__name__)


class QuotaWarningService:
    def __init__(self, session_factory: sessionmaker | None = None) -> None:
        if session_factory is None:
            from app.database import WorkerSessionLocal
            session_factory = WorkerSessionLocal
        self._session_factory = session_factory

    @staticmethod
    def _notify(db: Session, tenant: Tenant, warning: dict) -> None:
        from app.services.email_service import EmailService

        service = EmailService()
        if not service.configured:
            return
        rows = (
            db.query(User.email)
            .join(Membership, Membership.user_id == User.id)
            .filter(
                Membership.tenant_id == tenant.id,
                Membership.role.in_(["owner", "admin"]),
            )
            .all()
        )
        for (email,) in rows:
            service.send_quota_warning(
                to=email, tenant_name=tenant.name,
                resource=warning["resource"], used=warning["used"],
                limit=warning["limit"],
            )

    def tick_once(self, db: Session | None = None) -> int:
        if db is None:
            db = self._session_factory()
        created = 0
        try:
            now = datetime.now(timezone.utc).replace(tzinfo=None)
            cutoff = now - timedelta(hours=24)
            for tenant in db.query(Tenant).all():
                usage = {
                    "members": db.scalar(
                        select(func.count()).select_from(Membership).where(
                            Membership.tenant_id == tenant.id
                        )
                    ) or 0,
                    "strategies": db.scalar(
                        select(func.count()).select_from(StrategyV2).where(
                            StrategyV2.tenant_id == tenant.id
                        )
                    ) or 0,
                }
                for warning in quota_warnings(
                    tenant.plan, usage, settings.tenant_quota_warn_ratio
                ):
                    recent = db.query(TenantAuditLog).filter(
                        TenantAuditLog.tenant_id == tenant.id,
                        TenantAuditLog.action == "quota.warning",
                        TenantAuditLog.created_at >= cutoff,
                    ).all()
                    if any(
                        (row.detail or {}).get("resource") == warning["resource"]
                        for row in recent
                    ):
                        continue
                    record_tenant_audit(
                        db, tenant.id, "quota.warning", detail=warning
                    )
                    created += 1
                    self._notify(db, tenant, warning)
            db.commit()
            return created
        except Exception:
            db.rollback()
            logger.exception("quota warning tick failed")
            return 0
        finally:
            db.close()


class QuotaWarningScheduler:
    def __init__(self, interval_hours: int | None = None, service=None) -> None:
        hours = (
            interval_hours if interval_hours is not None
            else settings.tenant_quota_warn_interval_hours
        )
        self.interval_s = max(0, hours) * 3600
        self.enabled = self.interval_s > 0
        self._service = service or QuotaWarningService()
        self._task: asyncio.Task | None = None
        self._stop = asyncio.Event()

    async def start(self) -> None:
        if not self.enabled or self._task is not None:
            return
        self._task = asyncio.create_task(self._loop(), name="quota-warnings")

    async def stop(self) -> None:
        if self._task is None:
            return
        self._stop.set()
        try:
            await asyncio.wait_for(self._task, timeout=5.0)
        except asyncio.TimeoutError:
            self._task.cancel()
        self._task = None

    async def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                self._service.tick_once()
            except Exception:
                logger.exception("quota warning loop error")
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self.interval_s)
            except asyncio.TimeoutError:
                continue
