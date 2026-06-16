"""Provider health scheduler — native asyncio, zero new dependencies."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.database import SessionLocal
from app.models.provider_config import ProviderConfig
from app.services.providers.health_service import ProviderHealthService

logger = logging.getLogger(__name__)


class ProviderHealthTickPolicy:
    """Pure / unit-testable: pick which providers to test in a tick."""

    def __init__(self, batch_size: int = 10) -> None:
        self.batch_size = batch_size

    def select(
        self, rows: list[ProviderConfig], now: datetime | None = None
    ) -> list[ProviderConfig]:
        now = now or datetime.now(timezone.utc)
        eligible = [r for r in rows if r.enabled]
        # Sort: NULLS FIRST, then by last_sync_at ASC.
        eligible.sort(
            key=lambda r: (r.last_sync_at is not None, r.last_sync_at or now)
        )
        return eligible[: self.batch_size]


class ProviderHealthScheduler:
    """Periodically tests enabled providers using ProviderHealthService."""

    def __init__(
        self,
        interval_s: int | None = None,
        batch_size: int | None = None,
        session_factory: sessionmaker | None = None,
        health_service: ProviderHealthService | None = None,
    ) -> None:
        self.interval_s = interval_s if interval_s is not None else settings.provider_health_interval_s
        self.batch_size = batch_size if batch_size is not None else settings.provider_health_batch_size
        self.enabled = (
            self.interval_s > 0
            and settings.provider_health_enabled
        )
        self._session_factory = session_factory or SessionLocal
        self._health = health_service or ProviderHealthService(
            registry=self._build_registry()
        )
        self._task: asyncio.Task | None = None
        self._stop = asyncio.Event()

    @staticmethod
    def _build_registry():
        from app.services.providers.registry import registry
        return registry

    async def start(self) -> None:
        if not self.enabled:
            logger.info("Provider health scheduler disabled (interval_s=0)")
            return
        if self._task is not None:
            return
        from app.services.providers.categories import register_all  # noqa: F401
        self._task = asyncio.create_task(self._loop(), name="provider-health-scheduler")
        logger.info(
            "Provider health scheduler started (interval_s=%s, batch_size=%s)",
            self.interval_s, self.batch_size,
        )

    async def stop(self) -> None:
        if self._task is None:
            return
        self._stop.set()
        try:
            await asyncio.wait_for(self._task, timeout=5.0)
        except asyncio.TimeoutError:
            self._task.cancel()
        self._task = None
        logger.info("Provider health scheduler stopped")

    async def tick_once(self, db: Session | None = None) -> int:
        from app.services.providers.registry import registry

        if db is None:
            db = self._session_factory()
        try:
            rows = db.execute(
                select(ProviderConfig).order_by(
                    ProviderConfig.last_sync_at.asc().nulls_first()
                )
            ).scalars().all()
            policy = ProviderHealthTickPolicy(batch_size=self.batch_size)
            selected = policy.select(rows)
            if not selected:
                return 0
            tested = 0
            async with asyncio.TaskGroup() as tg:
                for row in selected:
                    tg.create_task(self._safe_test(db, row))
                    tested += 1
            db.commit()
            return tested
        finally:
            try:
                db.close()
            except Exception:
                pass

    async def _safe_test(self, db: Session, row: ProviderConfig) -> None:
        try:
            await self._health.test_from_row(db, row)
        except Exception:
            logger.exception("Provider test failed for id=%s", row.id)

    async def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self.interval_s)
                return
            except asyncio.TimeoutError:
                pass
            try:
                await self.tick_once()
            except Exception:
                logger.exception("Provider health tick failed")
