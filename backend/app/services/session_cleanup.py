"""Periodic cleanup of expired/revoked device sessions."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import or_
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.models.tenant import DeviceSession

logger = logging.getLogger(__name__)


class SessionCleanupService:
    def __init__(self, session_factory: sessionmaker | None = None) -> None:
        if session_factory is None:
            from app.database import WorkerSessionLocal
            session_factory = WorkerSessionLocal
        self._session_factory = session_factory

    def tick_once(self, db: Session | None = None, retention_days: int | None = None) -> int:
        if db is None:
            db = self._session_factory()
        days = retention_days if retention_days is not None else settings.session_retention_days
        cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days)
        try:
            rows = db.query(DeviceSession).filter(
                or_(
                    DeviceSession.revoked_at.isnot(None) & (DeviceSession.revoked_at < cutoff),
                    DeviceSession.expires_at.isnot(None) & (DeviceSession.expires_at < cutoff),
                )
            ).all()
            for row in rows:
                db.delete(row)
            db.commit()
            return len(rows)
        except Exception:
            db.rollback()
            logger.exception("session cleanup failed")
            return 0
        finally:
            db.close()


class SessionCleanupScheduler:
    def __init__(self, interval_hours: int | None = None, service=None) -> None:
        hours = (
            interval_hours if interval_hours is not None
            else settings.session_cleanup_interval_hours
        )
        self.interval_s = max(0, hours) * 3600
        self.enabled = self.interval_s > 0
        self._service = service or SessionCleanupService()
        self._task: asyncio.Task | None = None
        self._stop = asyncio.Event()

    async def start(self) -> None:
        if not self.enabled or self._task is not None:
            return
        self._task = asyncio.create_task(self._loop(), name="session-cleanup")
        logger.info("session cleanup scheduler started (%ss)", self.interval_s)

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
                logger.exception("session cleanup loop error")
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self.interval_s)
            except asyncio.TimeoutError:
                continue
