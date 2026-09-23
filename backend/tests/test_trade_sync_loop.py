"""Tests for TradeSyncLoop background task."""
import asyncio
import uuid
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, AsyncMock

import pytest
from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.ledger import ExecutionLedgerEvent
from app.repositories.ledger_repository import LedgerRepository
from app.workers.trade_sync_loop import TradeSyncLoop, _utcnow


def _make_ft_run(session: Session, status="running", heartbeat_ago_s: int = 10) -> FreqtradeRun:
    run = StrategyRun(
        strategy_version_id=uuid.uuid4(),
        mode="dry_run",
        status="running",
    )
    session.add(run)
    session.flush()

    ft_run = FreqtradeRun(
        strategy_run_id=run.id,
        config_path="/tmp/config.json",
        rules_path="/tmp/rules.json",
        rule_package_hash="abc123",
        status=status,
        api_base_url="http://localhost:8080",
        last_heartbeat_at=_utcnow() - timedelta(seconds=heartbeat_ago_s),
    )
    session.add(ft_run)
    session.flush()
    return ft_run


class TestTradeSyncLoop:
    @pytest.mark.asyncio
    async def test_starts_and_stops(self):
        loop = TradeSyncLoop(sync_interval_s=0.1, enabled=True)
        await loop.start()
        assert loop._task is not None
        await asyncio.sleep(0.15)
        await loop.stop()
        assert loop._task is None

    @pytest.mark.asyncio
    async def test_disabled(self):
        loop = TradeSyncLoop(enabled=False)
        await loop.start()
        assert loop._task is None

    def test_get_active_runs(self, session: Session):
        ft_running = _make_ft_run(session, status="running")
        ft_degraded = _make_ft_run(session, status="degraded")
        ft_stopped = _make_ft_run(session, status="stopped")
        session.commit()

        loop = TradeSyncLoop()
        active = loop._get_active_runs(session)
        active_ids = {r.id for r in active}
        assert ft_running.id in active_ids
        assert ft_degraded.id in active_ids
        assert ft_stopped.id not in active_ids

    @pytest.mark.asyncio
    async def test_heartbeat_failure_degrades_run(self, session: Session):
        ft_run = _make_ft_run(session, status="running", heartbeat_ago_s=60)
        session.commit()

        loop = TradeSyncLoop(heartbeat_stale_s=30)

        with patch("app.workers.trade_sync_loop.FreqtradeClient") as mock_cls:
            mock_client = mock_cls.return_value
            mock_client.ping = AsyncMock(return_value={"error": "timeout"})
            mock_cls.is_success = lambda x: "error" not in x

            loop._handle_heartbeat_failure(session, ft_run)
            session.commit()

        refreshed = session.get(FreqtradeRun, ft_run.id)
        assert refreshed.status == "degraded"

        # Verify ledger event was written
        from sqlalchemy import select
        events = list(session.scalars(
            select(ExecutionLedgerEvent).where(
                ExecutionLedgerEvent.freqtrade_run_id == ft_run.id
            )
        ).all())
        assert len(events) == 1
        assert events[0].event_type == "FREQTRADE_RUN_DEGRADED"

    def test_no_double_degrade(self, session: Session):
        """Already degraded run should not generate duplicate events."""
        ft_run = _make_ft_run(session, status="degraded", heartbeat_ago_s=60)
        session.commit()

        loop = TradeSyncLoop(heartbeat_stale_s=30)
        loop._handle_heartbeat_failure(session, ft_run)
        session.commit()

        # Should still be degraded, no new event
        from sqlalchemy import select
        events = list(session.scalars(
            select(ExecutionLedgerEvent).where(
                ExecutionLedgerEvent.freqtrade_run_id == ft_run.id
            )
        ).all())
        assert len(events) == 0  # not written because already degraded


class TestCircuitBreakerIntegration:
    """Circuit breaker auto-trigger via TradeSyncLoop."""

    def test_circuit_breaker_triggers_emergency_stop(self, session: Session):
        """When daily loss exceeds threshold, emergency_stop command is submitted."""
        from app.domain.execution import StrategyRun
        from app.domain.command import CommandBusCommand

        run = StrategyRun(
            strategy_version_id=uuid.uuid4(),
            mode="live_small",
            status="running",
        )
        session.add(run)
        session.flush()

        ft_run = FreqtradeRun(
            strategy_run_id=run.id,
            config_path="/tmp/config.json",
            rules_path="/tmp/rules.json",
            rule_package_hash="abc",
            status="running",
            api_base_url="http://localhost:8080",
            last_heartbeat_at=_utcnow(),
        )
        session.add(ft_run)
        session.flush()

        # Add losing trades today that exceed 3% daily loss
        today_start = _utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        ledger = LedgerRepository(session)
        for i in range(5):
            now = _utcnow()
            payload = {"profit_abs": -100.0, "profit_ratio": -0.01, "trade_id": f"loss-{i}"}
            event_hash = LedgerRepository.compute_event_hash(
                "freqtrade", f"loss-{ft_run.id}-{i}", "FREQTRADE_TRADE_CLOSED", payload, now,
            )
            evt = ExecutionLedgerEvent(
                id=uuid.uuid4(), event_time=now,
                event_type="FREQTRADE_TRADE_CLOSED",
                source_system="freqtrade",
                source_event_id=f"loss-{ft_run.id}-{i}",
                event_hash=event_hash,
                strategy_run_id=run.id,
                freqtrade_run_id=ft_run.id,
                normalized_payload=payload,
            )
            ledger.append(evt)
        session.commit()

        # Run circuit breaker check
        loop = TradeSyncLoop(heartbeat_stale_s=30)
        loop._check_circuit_breaker(session, ft_run)
        session.commit()

        # Verify emergency_stop command was submitted
        from sqlalchemy import select
        cmds = list(session.scalars(
            select(CommandBusCommand).where(
                CommandBusCommand.command_type == "emergency_stop"
            )
        ).all())
        assert len(cmds) == 1
        assert cmds[0].payload["trigger"] == "circuit_breaker"
        assert cmds[0].payload["freqtrade_run_id"] == str(ft_run.id)

        # Verify CIRCUIT_BREAKER_TRIPPED ledger event
        cb_events = list(session.scalars(
            select(ExecutionLedgerEvent).where(
                ExecutionLedgerEvent.event_type == "CIRCUIT_BREAKER_TRIPPED"
            )
        ).all())
        assert len(cb_events) == 1

    def test_circuit_breaker_not_triggered_below_threshold(self, session: Session):
        """Small losses don't trigger circuit breaker."""
        from app.domain.execution import StrategyRun
        from app.domain.command import CommandBusCommand

        run = StrategyRun(
            strategy_version_id=uuid.uuid4(),
            mode="dry_run",
            status="running",
        )
        session.add(run)
        session.flush()

        ft_run = FreqtradeRun(
            strategy_run_id=run.id,
            config_path="/tmp/config.json",
            rules_path="/tmp/rules.json",
            rule_package_hash="abc",
            status="running",
            api_base_url="http://localhost:8080",
            last_heartbeat_at=_utcnow(),
        )
        session.add(ft_run)
        session.flush()

        # Add small winning trades
        ledger = LedgerRepository(session)
        now = _utcnow()
        payload = {"profit_abs": 50.0, "profit_ratio": 0.005, "trade_id": "win-0"}
        event_hash = LedgerRepository.compute_event_hash(
            "freqtrade", f"win-{ft_run.id}-0", "FREQTRADE_TRADE_CLOSED", payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(), event_time=now,
            event_type="FREQTRADE_TRADE_CLOSED",
            source_system="freqtrade",
            source_event_id=f"win-{ft_run.id}-0",
            event_hash=event_hash,
            strategy_run_id=run.id,
            normalized_payload=payload,
        )
        ledger.append(evt)
        session.commit()

        loop = TradeSyncLoop(heartbeat_stale_s=30)
        loop._check_circuit_breaker(session, ft_run)
        session.commit()

        # No emergency_stop submitted
        from sqlalchemy import select
        cmds = list(session.scalars(
            select(CommandBusCommand).where(
                CommandBusCommand.command_type == "emergency_stop"
            )
        ).all())
        assert len(cmds) == 0

    def test_circuit_breaker_idempotent_per_day(self, session: Session):
        """Same-day circuit breaker only submits one command."""
        from app.domain.execution import StrategyRun
        from app.domain.command import CommandBusCommand

        run = StrategyRun(
            strategy_version_id=uuid.uuid4(),
            mode="live_small",
            status="running",
        )
        session.add(run)
        session.flush()

        ft_run = FreqtradeRun(
            strategy_run_id=run.id,
            config_path="/tmp/config.json",
            rules_path="/tmp/rules.json",
            rule_package_hash="abc",
            status="running",
            api_base_url="http://localhost:8080",
            last_heartbeat_at=_utcnow(),
        )
        session.add(ft_run)
        session.flush()

        # Add big losses
        ledger = LedgerRepository(session)
        for i in range(5):
            now = _utcnow()
            payload = {"profit_abs": -100.0, "profit_ratio": -0.01, "trade_id": f"l-{i}"}
            event_hash = LedgerRepository.compute_event_hash(
                "freqtrade", f"l2-{ft_run.id}-{i}", "FREQTRADE_TRADE_CLOSED", payload, now,
            )
            evt = ExecutionLedgerEvent(
                id=uuid.uuid4(), event_time=now,
                event_type="FREQTRADE_TRADE_CLOSED",
                source_system="freqtrade",
                source_event_id=f"l2-{ft_run.id}-{i}",
                event_hash=event_hash,
                strategy_run_id=run.id,
                normalized_payload=payload,
            )
            ledger.append(evt)
        session.commit()

        loop = TradeSyncLoop(heartbeat_stale_s=30)
        loop._check_circuit_breaker(session, ft_run)
        session.commit()
        # Call again — should not create second command
        loop._check_circuit_breaker(session, ft_run)
        session.commit()

        from sqlalchemy import select
        cmds = list(session.scalars(
            select(CommandBusCommand).where(
                CommandBusCommand.command_type == "emergency_stop"
            )
        ).all())
        assert len(cmds) == 1  # Idempotent
