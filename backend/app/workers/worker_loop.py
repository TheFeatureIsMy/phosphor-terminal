"""CommandWorkerLoop — asyncio background task that continuously polls the Command Bus."""
from __future__ import annotations

import asyncio
import functools
import logging
import time

from sqlalchemy.orm import sessionmaker

from app.config import settings
from app.database import WorkerSessionLocal
from app.workers.command_worker import CommandWorker

logger = logging.getLogger(__name__)


class CommandWorkerLoop:
    def __init__(
        self,
        session_factory: sessionmaker | None = None,
        poll_interval_s: float | None = None,
        stale_recovery_interval_s: float | None = None,
        enabled: bool | None = None,
    ) -> None:
        self._session_factory = session_factory or WorkerSessionLocal
        self._poll_interval = poll_interval_s if poll_interval_s is not None else settings.command_worker_poll_interval_s
        self._stale_recovery_interval = stale_recovery_interval_s if stale_recovery_interval_s is not None else settings.command_worker_stale_recovery_s
        self._enabled = enabled if enabled is not None else settings.command_worker_enabled
        self._stop = asyncio.Event()
        self._task: asyncio.Task | None = None

    async def start(self) -> None:
        if not self._enabled:
            logger.info("Command worker loop disabled")
            return
        if self._task is not None:
            return
        self._task = asyncio.create_task(self._loop(), name="command-worker-loop")
        logger.info(
            "Command worker loop started (poll_interval=%.1fs, stale_recovery=%.0fs)",
            self._poll_interval, self._stale_recovery_interval,
        )

    async def stop(self) -> None:
        if self._task is None:
            return
        self._stop.set()
        try:
            await asyncio.wait_for(self._task, timeout=10.0)
        except asyncio.TimeoutError:
            self._task.cancel()
        self._task = None
        logger.info("Command worker loop stopped")

    async def _loop(self) -> None:
        last_recovery = time.monotonic()
        while not self._stop.is_set():
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self._poll_interval)
                return
            except asyncio.TimeoutError:
                pass

            await self._tick()

            if time.monotonic() - last_recovery > self._stale_recovery_interval:
                await self._recover_stale()
                last_recovery = time.monotonic()

    async def _tick(self) -> None:
        # Run in thread to avoid blocking event loop during subprocess-based handlers
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, self._tick_sync)

    def _tick_sync(self) -> None:
        db = self._session_factory()
        try:
            worker = CommandWorker(db)
            worker.poll_once()
        except Exception:
            db.rollback()
            logger.exception("Command worker tick failed")
        else:
            db.commit()
        finally:
            db.close()

    async def _recover_stale(self) -> None:
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, self._recover_stale_sync)

    def _recover_stale_sync(self) -> None:
        db = self._session_factory()
        try:
            worker = CommandWorker(db)
            recovered = worker.recover_stale()
            if recovered:
                db.commit()
                logger.info("Recovered %d stale commands", recovered)
            else:
                db.commit()
        except Exception:
            db.rollback()
            logger.exception("Stale command recovery failed")
        finally:
            db.close()
