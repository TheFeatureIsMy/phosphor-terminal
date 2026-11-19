"""TradeSyncLoop — periodically syncs Freqtrade trades into Execution Ledger."""
from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import datetime, timezone, timedelta

from sqlalchemy import select, and_
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.database import WorkerSessionLocal
from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.ledger import ExecutionLedgerEvent
from app.domain.risk import CapitalPool
from app.repositories.ledger_repository import LedgerRepository
from app.services.command_bus import CommandBusService
from app.services.dryrun_sync import DryRunSyncService
from app.services.freqtrade_client import FreqtradeClient
from app.services.live_small.circuit_breaker import check_circuit_breaker, TradeResult

logger = logging.getLogger(__name__)


def _naive(value: datetime | None) -> datetime | None:
    return value.replace(tzinfo=None) if value is not None and value.tzinfo else value


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class TradeSyncLoop:
    def __init__(
        self,
        session_factory: sessionmaker | None = None,
        sync_interval_s: float | None = None,
        heartbeat_stale_s: int | None = None,
        enabled: bool | None = None,
    ) -> None:
        self._session_factory = session_factory or WorkerSessionLocal
        self._sync_interval = sync_interval_s if sync_interval_s is not None else settings.trade_sync_interval_s
        self._heartbeat_stale_s = heartbeat_stale_s if heartbeat_stale_s is not None else settings.trade_sync_heartbeat_stale_s
        self._enabled = enabled if enabled is not None else settings.trade_sync_enabled
        self._stop = asyncio.Event()
        self._task: asyncio.Task | None = None

    async def start(self) -> None:
        if not self._enabled:
            logger.info("Trade sync loop disabled")
            return
        if self._task is not None:
            return
        self._task = asyncio.create_task(self._loop(), name="trade-sync-loop")
        logger.info(
            "Trade sync loop started (interval=%.1fs, heartbeat_stale=%ds)",
            self._sync_interval, self._heartbeat_stale_s,
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
        logger.info("Trade sync loop stopped")

    async def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self._sync_interval)
                return
            except asyncio.TimeoutError:
                pass
            await self._tick()

    async def _tick(self) -> None:
        db = self._session_factory()
        try:
            active_runs = self._get_active_runs(db)
            for ft_run in active_runs:
                await self._sync_single_run(db, ft_run)
            db.commit()
        except Exception:
            db.rollback()
            logger.exception("Trade sync tick failed")
        finally:
            db.close()

    def _get_active_runs(self, db: Session) -> list[FreqtradeRun]:
        stmt = select(FreqtradeRun).where(
            FreqtradeRun.status.in_(["running", "degraded"])
        )
        return list(db.scalars(stmt).all())

    async def _sync_single_run(self, db: Session, ft_run: FreqtradeRun) -> None:
        api_url = ft_run.api_base_url or settings.freqtrade_url
        client = FreqtradeClient(base_url=api_url)

        # 1. Heartbeat check
        ping_result = await client.ping()
        alive = FreqtradeClient.is_success(ping_result)

        if alive:
            ft_run.last_heartbeat_at = _utcnow()
            if ft_run.status == "degraded":
                ft_run.status = "running"
                logger.info("FreqtradeRun %s recovered from degraded", ft_run.id)
        else:
            self._handle_heartbeat_failure(db, ft_run)
            return

        # 2. Sync trades into Ledger
        sync_svc = DryRunSyncService(db, api_url=api_url)
        correlation_id = uuid.uuid5(uuid.NAMESPACE_DNS, f"sync-{ft_run.id}")
        try:
            result = await sync_svc.sync_trades(
                dryrun_run_id=ft_run.id,
                correlation_id=correlation_id,
            )
            if result.new_events > 0:
                await self._broadcast_trade_update(ft_run, result)
                logger.debug(
                    "Synced %d new events for FreqtradeRun %s",
                    result.new_events, ft_run.id,
                )
        except Exception:
            logger.exception("Trade sync failed for FreqtradeRun %s", ft_run.id)

        # 2b. Materialize orders/trades/positions from Ledger events
        try:
            from app.services.order_materializer import OrderMaterializerService
            mat_svc = OrderMaterializerService(db)
            mat_svc.materialize_for_run(ft_run.strategy_run_id)
        except Exception:
            logger.debug("Order materialization skipped for run %s", ft_run.strategy_run_id)

        # 3. Circuit breaker check
        self._check_circuit_breaker(db, ft_run)

        # 4. Strategy promotion check
        try:
            from app.services.strategy_promotion_service import StrategyPromotionService
            promo_svc = StrategyPromotionService(db)
            promo_svc.promote_if_eligible(ft_run.strategy_run_id)
        except Exception:
            logger.debug("Promotion check skipped for run %s", ft_run.strategy_run_id)

    def _check_circuit_breaker(self, db: Session, ft_run: FreqtradeRun) -> None:
        """Check circuit breaker conditions and submit emergency_stop if triggered."""
        strategy_run = db.get(StrategyRun, ft_run.strategy_run_id)
        if not strategy_run:
            return

        # Get today's closed trades from Ledger
        today_start = _utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        stmt = (
            select(ExecutionLedgerEvent)
            .where(and_(
                ExecutionLedgerEvent.strategy_run_id == ft_run.strategy_run_id,
                ExecutionLedgerEvent.event_type == "FREQTRADE_TRADE_CLOSED",
                ExecutionLedgerEvent.event_time >= today_start,
            ))
        )
        today_events = list(db.scalars(stmt).all())

        if not today_events:
            return

        # Convert to TradeResult
        trades_today = []
        for evt in today_events:
            payload = evt.normalized_payload or {}
            profit_abs = float(payload.get("profit_abs") or 0)
            profit_pct = float(payload.get("profit_ratio") or 0)
            trades_today.append(TradeResult(
                profit_abs=profit_abs,
                profit_pct=profit_pct,
                is_win=profit_abs > 0,
            ))

        # Get budget from CapitalPool if available
        total_budget = 10000.0  # default
        if strategy_run.capital_pool_id:
            pool = db.get(CapitalPool, strategy_run.capital_pool_id)
            if pool:
                total_budget = float(pool.total_budget)

        # Run circuit breaker check
        cb_result = check_circuit_breaker(trades_today, total_budget)

        if cb_result["should_stop"]:
            logger.warning(
                "Circuit breaker TRIGGERED for FreqtradeRun %s: %s",
                ft_run.id, cb_result["reasons"],
            )
            self._submit_emergency_stop(db, ft_run, cb_result)

    def _submit_emergency_stop(self, db: Session, ft_run: FreqtradeRun, cb_result: dict) -> None:
        """Submit an emergency_stop command via Command Bus."""
        cmd_svc = CommandBusService(db)
        idemp_key = f"circuit-breaker-{ft_run.id}-{_utcnow().strftime('%Y%m%d')}"

        cmd, created = cmd_svc.enqueue(
            command_type="emergency_stop",
            aggregate_type="strategy_run",
            aggregate_id=ft_run.strategy_run_id,
            payload={
                "freqtrade_run_id": str(ft_run.id),
                "strategy_run_id": str(ft_run.strategy_run_id),
                "trigger": "circuit_breaker",
                "reasons": cb_result["reasons"],
                "daily_loss_pct": cb_result["daily_loss_pct"],
                "consecutive_losses": cb_result["consecutive_losses"],
            },
            requested_by="trade_sync_loop:circuit_breaker",
            idempotency_key=idemp_key,
        )

        if created:
            logger.warning(
                "Emergency stop command submitted for FreqtradeRun %s (cmd=%s)",
                ft_run.id, cmd.id,
            )
            # Write circuit breaker event to ledger
            ledger = LedgerRepository(db)
            now = _utcnow()
            payload = {
                "freqtrade_run_id": str(ft_run.id),
                "reasons": cb_result["reasons"],
                "daily_loss_pct": cb_result["daily_loss_pct"],
                "consecutive_losses": cb_result["consecutive_losses"],
            }
            event_hash = LedgerRepository.compute_event_hash(
                "pulsedesk", idemp_key, "CIRCUIT_BREAKER_TRIPPED", payload, now,
            )
            evt = ExecutionLedgerEvent(
                id=uuid.uuid4(),
                event_time=now,
                event_type="CIRCUIT_BREAKER_TRIPPED",
                source_system="pulsedesk",
                source_event_id=idemp_key,
                event_hash=event_hash,
                strategy_run_id=ft_run.strategy_run_id,
                freqtrade_run_id=ft_run.id,
                normalized_payload=payload,
            )
            ledger.append(evt)
        else:
            logger.debug("Circuit breaker stop already submitted today for %s", ft_run.id)

    def _handle_heartbeat_failure(self, db: Session, ft_run: FreqtradeRun) -> None:
        if ft_run.last_heartbeat_at:
            elapsed = (_utcnow() - _naive(ft_run.last_heartbeat_at)).total_seconds()
        else:
            elapsed = float("inf")

        if elapsed > self._heartbeat_stale_s and ft_run.status != "degraded":
            ft_run.status = "degraded"
            self._write_degraded_event(db, ft_run)
            logger.warning("FreqtradeRun %s degraded (no heartbeat for %.0fs)", ft_run.id, elapsed)
            asyncio.get_event_loop().create_task(self._broadcast_alert(ft_run, "degraded", f"No heartbeat for {int(elapsed)}s"))

    def _write_degraded_event(self, db: Session, ft_run: FreqtradeRun) -> None:
        ledger = LedgerRepository(db)
        now = _utcnow()
        payload = {
            "freqtrade_run_id": str(ft_run.id),
            "reason": "heartbeat_timeout",
            "stale_threshold_s": self._heartbeat_stale_s,
        }
        event_hash = LedgerRepository.compute_event_hash(
            "pulsedesk", f"degraded-{ft_run.id}", "FREQTRADE_RUN_DEGRADED", payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(),
            event_time=now,
            event_type="FREQTRADE_RUN_DEGRADED",
            source_system="pulsedesk",
            source_event_id=f"degraded-{ft_run.id}",
            event_hash=event_hash,
            strategy_run_id=ft_run.strategy_run_id,
            freqtrade_run_id=ft_run.id,
            normalized_payload=payload,
        )
        ledger.append(evt)

    async def _broadcast_trade_update(self, ft_run: FreqtradeRun, sync_result) -> None:
        """Broadcast trade sync updates to WebSocket subscribers."""
        try:
            from app.routers.websocket import manager
            await manager.broadcast("trades", {
                "freqtrade_run_id": str(ft_run.id),
                "strategy_run_id": str(ft_run.strategy_run_id),
                "new_events": sync_result.new_events,
                "open_trades": sync_result.open_trades,
                "closed_trades": sync_result.closed_trades,
                "timestamp": _utcnow().isoformat(),
            })
        except Exception:
            pass  # Non-critical — don't break sync loop

    async def _broadcast_alert(self, ft_run: FreqtradeRun, alert_type: str, message: str) -> None:
        """Broadcast alert events to WebSocket subscribers."""
        try:
            from app.routers.websocket import manager
            await manager.broadcast("alerts", {
                "type": alert_type,
                "freqtrade_run_id": str(ft_run.id),
                "strategy_run_id": str(ft_run.strategy_run_id),
                "message": message,
                "timestamp": _utcnow().isoformat(),
            })
        except Exception:
            pass
