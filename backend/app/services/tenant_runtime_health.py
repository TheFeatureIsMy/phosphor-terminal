"""Periodic health checks for dedicated tenant execution runtimes."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.models.tenant import TenantExecutionProfile

logger = logging.getLogger(__name__)


class TenantRuntimeHealthService:
    def __init__(self, session_factory: sessionmaker | None = None) -> None:
        if session_factory is None:
            from app.database import WorkerSessionLocal
            session_factory = WorkerSessionLocal
        self._session_factory = session_factory

    async def tick_once(
        self,
        db: Session | None = None,
        limit: int | None = None,
        client_factory=None,
    ) -> int:
        if db is None:
            db = self._session_factory()
        if client_factory is None:
            from app.services.freqtrade_client import FreqtradeClient
            client_factory = FreqtradeClient
        limit = limit or settings.tenant_runtime_health_batch_size
        try:
            rows = db.execute(
                select(TenantExecutionProfile)
                .where(
                    TenantExecutionProfile.enabled.is_(True),
                    TenantExecutionProfile.mode == "dedicated",
                    TenantExecutionProfile.freqtrade_url.is_not(None),
                )
                .order_by(TenantExecutionProfile.last_health_at.asc().nulls_first())
                .limit(limit)
            ).scalars().all()
            tested = 0
            for row in rows:
                reachable = await client_factory(base_url=row.freqtrade_url).ping()
                row.runtime_status = "healthy" if reachable else "unreachable"
                row.last_health_at = datetime.now(timezone.utc)
                row.last_error = None if reachable else "ping failed"
                tested += 1
            db.commit()
            return tested
        except Exception:
            db.rollback()
            logger.exception("tenant runtime health tick failed")
            return 0
        finally:
            db.close()


class TenantRuntimeHealthScheduler:
    def __init__(self, interval_s: int | None = None, service=None) -> None:
        self.interval_s = (
            interval_s if interval_s is not None
            else settings.tenant_runtime_health_interval_s
        )
        self.enabled = self.interval_s > 0
        self._service = service or TenantRuntimeHealthService()
        self._task: asyncio.Task | None = None
        self._stop = asyncio.Event()

    async def start(self) -> None:
        if not self.enabled or self._task is not None:
            return
        self._task = asyncio.create_task(self._loop(), name="tenant-runtime-health")
        logger.info("tenant runtime health scheduler started (%ss)", self.interval_s)

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
                await self._service.tick_once()
            except Exception:
                logger.exception("tenant runtime health loop error")
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self.interval_s)
            except asyncio.TimeoutError:
                continue
