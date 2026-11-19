"""Periodic deletion of audit rows older than the retention window."""
from __future__ import annotations

import asyncio
import gzip
import json
import logging
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.models.tenant import Tenant, TenantAuditLog

logger = logging.getLogger(__name__)


class AuditCleanupService:
    def __init__(self, session_factory: sessionmaker | None = None) -> None:
        if session_factory is None:
            from app.database import WorkerSessionLocal
            session_factory = WorkerSessionLocal
        self._session_factory = session_factory

    @staticmethod
    def _archive(directory: str, tenant_id: int | None, rows) -> None:
        """Write JSONL.gz before deleting; failure aborts the tick (no data loss)."""
        root = Path(directory)
        root.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        label = f"tenant-{tenant_id}" if tenant_id is not None else "all"
        target = root / f"{label}-{stamp}.jsonl.gz"
        tmp = target.with_suffix(".tmp")
        with gzip.open(tmp, "wt", encoding="utf-8") as fh:
            for row in rows:
                fh.write(json.dumps({
                    "id": row.id,
                    "tenant_id": row.tenant_id,
                    "actor_user_id": row.actor_user_id,
                    "action": row.action,
                    "detail": row.detail or {},
                    "created_at": row.created_at.isoformat() if row.created_at else None,
                }, ensure_ascii=False) + "\n")
        os.replace(tmp, target)
        if settings.tenant_audit_archive_s3_bucket:
            import boto3

            client = boto3.client(
                "s3",
                endpoint_url=settings.tenant_audit_archive_s3_endpoint or None,
            )
            key = f"{settings.tenant_audit_archive_s3_prefix.strip('/')}/{target.name}"
            client.upload_file(str(target), settings.tenant_audit_archive_s3_bucket, key)

    def tick_once(self, db: Session | None = None, retention_days: int | None = None) -> int:
        if db is None:
            db = self._session_factory()
        try:
            if retention_days is not None:
                plan_windows = [(None, retention_days)]
            else:
                from app.services.tenant_limits import limits_for

                plan_windows = [
                    (tenant.id, limits_for(tenant.plan)["audit_days"])
                    for tenant in db.query(Tenant).all()
                ]
            now = datetime.now(timezone.utc).replace(tzinfo=None)
            deleted = 0
            archive_dir = settings.tenant_audit_archive_dir.strip()
            for tenant_id, days in plan_windows:
                if days <= 0:
                    continue
                cutoff = now - timedelta(days=days)
                query = db.query(TenantAuditLog).filter(
                    TenantAuditLog.created_at < cutoff
                )
                if tenant_id is not None:
                    query = query.filter(TenantAuditLog.tenant_id == tenant_id)
                rows = query.all()
                if rows and archive_dir:
                    self._archive(archive_dir, tenant_id, rows)
                for row in rows:
                    db.delete(row)
                deleted += len(rows)
            db.commit()
            return deleted
        except Exception:
            db.rollback()
            logger.exception("audit cleanup failed")
            return 0
        finally:
            db.close()


class AuditCleanupScheduler:
    def __init__(self, interval_hours: int | None = None, service=None) -> None:
        hours = (
            interval_hours if interval_hours is not None
            else settings.tenant_audit_cleanup_interval_hours
        )
        self.interval_s = max(0, hours) * 3600
        self.enabled = self.interval_s > 0
        self._service = service or AuditCleanupService()
        self._task: asyncio.Task | None = None
        self._stop = asyncio.Event()

    async def start(self) -> None:
        if not self.enabled or self._task is not None:
            return
        self._task = asyncio.create_task(self._loop(), name="audit-cleanup")
        logger.info("audit cleanup scheduler started (%ss)", self.interval_s)

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
                logger.exception("audit cleanup loop error")
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self.interval_s)
            except asyncio.TimeoutError:
                continue
