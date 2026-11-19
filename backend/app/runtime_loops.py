"""Background loop lifecycle shared by the API and the worker process."""
from __future__ import annotations

import asyncio

from app.services.providers.realtime.ccxt_ticker_stream import run_binance_ticker_stream
from app.workers.trade_sync_loop import TradeSyncLoop
from app.workers.worker_loop import CommandWorkerLoop


class BackgroundLoops:
    def __init__(self) -> None:
        self._sched = None
        self._runtime_health = None
        self._session_cleanup = None
        self._audit_cleanup = None
        self._quota_warnings = None
        self._subscription_expiry = None
        self._cmd_worker = None
        self._trade_sync = None
        self._ticker_task: asyncio.Task | None = None

    async def start(self) -> None:
        from app.services.providers.scheduler import ProviderHealthScheduler
        from app.services.session_cleanup import SessionCleanupScheduler
        from app.services.tenant_runtime_health import TenantRuntimeHealthScheduler

        self._sched = ProviderHealthScheduler()
        await self._sched.start()
        self._runtime_health = TenantRuntimeHealthScheduler()
        await self._runtime_health.start()
        self._session_cleanup = SessionCleanupScheduler()
        await self._session_cleanup.start()
        from app.services.audit_cleanup import AuditCleanupScheduler

        self._audit_cleanup = AuditCleanupScheduler()
        await self._audit_cleanup.start()
        from app.services.quota_warnings import QuotaWarningScheduler

        self._quota_warnings = QuotaWarningScheduler()
        await self._quota_warnings.start()
        from app.services.subscriptions import SubscriptionExpiryScheduler

        self._subscription_expiry = SubscriptionExpiryScheduler()
        await self._subscription_expiry.start()
        self._cmd_worker = CommandWorkerLoop()
        await self._cmd_worker.start()
        self._trade_sync = TradeSyncLoop()
        await self._trade_sync.start()
        self._ticker_task = asyncio.create_task(run_binance_ticker_stream())

    async def stop(self) -> None:
        if self._trade_sync is not None:
            await self._trade_sync.stop()
        if self._cmd_worker is not None:
            await self._cmd_worker.stop()
        if self._ticker_task is not None:
            self._ticker_task.cancel()
            try:
                await self._ticker_task
            except asyncio.CancelledError:
                pass
        for scheduler in (
            self._sched, self._runtime_health, self._session_cleanup,
            self._audit_cleanup, self._quota_warnings, self._subscription_expiry,
        ):
            if scheduler is not None:
                await scheduler.stop()
