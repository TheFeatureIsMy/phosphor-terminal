"""End-to-end integration test: command submit → worker poll → backtest handler → ledger events.

Mocks FreqtradeBacktestRunner to avoid needing actual Freqtrade process.
"""
import uuid
from unittest.mock import patch, MagicMock

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus
from app.domain.ledger import ExecutionLedgerEvent
from app.domain.strategy import StrategyV2, StrategyVersion
from app.services.command_bus import CommandBusService
from app.services.dsl_validator import DSLValidator
from app.services.dsl_hasher import compute_dsl_hash
from app.services.risk_engine import RiskEngine
from app.workers.command_worker import CommandWorker
from app.workers.handlers import _registry, register_handler
from app.workers.backtest_handler import StartBacktestHandler


VALID_DSL = {
    "schema_version": "2.5",
    "timeframe": "1h",
    "symbols": ["BTC/USDT"],
    "entry": {
        "logic": "AND",
        "rules": [
            {"type": "indicator_threshold", "indicator": "rsi",
             "params": {"period": 14}, "operator": "<", "value": 30},
        ],
    },
    "exit": {
        "logic": "OR",
        "rules": [
            {"type": "indicator_threshold", "indicator": "rsi",
             "params": {"period": 14}, "operator": ">", "value": 70},
        ],
    },
    "filters": [],
    "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
    "risk": {"stoploss": -0.05, "max_open_trades": 3},
    "metadata": {},
}


def _mock_backtest_result():
    """Return a mock BacktestResult simulating a successful run."""
    from app.services.backtest_runner import BacktestResult, BacktestMetrics
    return BacktestResult(
        success=True,
        metrics=BacktestMetrics(
            total_return_pct=12.5,
            sharpe_ratio=1.8,
            max_drawdown_pct=5.2,
            win_rate=0.65,
            profit_factor=2.1,
            total_trades=42,
            avg_trade_duration="4h 30m",
            best_trade_pct=3.2,
            worst_trade_pct=-1.1,
        ),
        trades=[
            {"pair": "BTC/USDT", "side": "long", "profit": 0.05,
             "open_time": "2024-01-05", "close_time": "2024-01-06",
             "open_price": 42000, "close_price": 44100,
             "quantity": 0.01, "duration": "1d"},
        ],
        equity_curve=[
            {"timestamp": "2024-01-01", "equity": 10000, "drawdown": 0},
            {"timestamp": "2024-01-31", "equity": 11250, "drawdown": 0.02},
        ],
        raw_result={},
        exit_code=0,
    )


@pytest.fixture(autouse=True)
def _setup_handlers():
    _registry.clear()
    register_handler("start_backtest", StartBacktestHandler)
    yield
    _registry.clear()


class TestE2ECommandWorkerBacktest:
    """Full end-to-end: create strategy → validate → risk check → submit command → worker processes → verify ledger."""

    def test_full_backtest_loop(self, session: Session):
        # 1. Create strategy + version
        strategy = StrategyV2(
            name="E2E Integration Test",
            strategy_type="rule_dsl",
            source_type="manual",
            status="draft",
        )
        session.add(strategy)
        session.flush()

        version = StrategyVersion(
            strategy_id=strategy.id,
            version_no=1,
            status="draft",
            dsl_version="2.5",
            rule_dsl=VALID_DSL,
            dsl_hash=compute_dsl_hash(VALID_DSL),
            created_by="e2e_test",
        )
        session.add(version)
        session.flush()
        session.commit()

        # 2. Validate DSL
        validator = DSLValidator()
        report = validator.validate(VALID_DSL)
        assert report.valid is True

        # 3. Risk pre-check
        engine = RiskEngine()
        risk_result = engine.pre_backtest_check(VALID_DSL, "20240101-20240201", 10000)
        assert risk_result.approved is True

        # 4. Submit command
        cmd_svc = CommandBusService(session)
        cmd, created = cmd_svc.enqueue(
            command_type="start_backtest",
            aggregate_type="strategy_version",
            aggregate_id=version.id,
            payload={
                "dsl": VALID_DSL,
                "strategy_version_id": str(version.id),
                "strategy_id": str(strategy.id),
                "timerange": "20240101-20240201",
                "initial_capital": 10000,
                "dsl_hash": compute_dsl_hash(VALID_DSL),
            },
            requested_by="e2e_test",
            idempotency_key=f"e2e-backtest-{uuid.uuid4()}",
        )
        session.commit()
        assert created is True
        assert cmd.status == CommandStatus.PENDING.value

        # 5. Worker processes the command (mock FreqtradeBacktestRunner)
        with patch(
            "app.workers.backtest_handler.FreqtradeBacktestRunner"
        ) as MockRunner:
            mock_instance = MockRunner.return_value
            mock_instance.run.return_value = _mock_backtest_result()

            worker = CommandWorker(session)
            processed = worker.poll_once()

        assert processed is True

        # 6. Verify command status
        refreshed_cmd = session.get(CommandBusCommand, cmd.id)
        assert refreshed_cmd.status == CommandStatus.SUCCEEDED.value
        assert refreshed_cmd.completed_at is not None

        # 7. Verify ledger events
        events = list(session.scalars(
            select(ExecutionLedgerEvent)
            .where(ExecutionLedgerEvent.command_id == cmd.id)
            .order_by(ExecutionLedgerEvent.event_time)
        ).all())

        event_types = [e.event_type for e in events]
        assert "PULSEDESK_COMMAND_STARTED" in event_types
        assert "FREQTRADE_BACKTEST_STARTED" in event_types
        assert "FREQTRADE_BACKTEST_COMPLETED" in event_types
        assert "PULSEDESK_COMMAND_SUCCEEDED" in event_types

        # 8. Verify backtest result in DB
        from app.models.strategy import BacktestRun
        bt_run = session.scalars(
            select(BacktestRun).where(BacktestRun.command_id == str(cmd.id))
        ).first()
        assert bt_run is not None
        assert bt_run.status == "completed"
        assert bt_run.total_trades == 42
        assert bt_run.sharpe_ratio == 1.8
        assert bt_run.win_rate == 0.65

        # 9. Verify correlation chain
        for evt in events:
            assert evt.causation_id == cmd.id

    def test_backtest_failure_writes_failed_events(self, session: Session):
        """When backtest fails, command goes to RETRY_WAITING and failure events are written."""
        strategy = StrategyV2(
            name="Fail Test", strategy_type="rule_dsl", source_type="manual", status="draft",
        )
        session.add(strategy)
        session.flush()

        version = StrategyVersion(
            strategy_id=strategy.id, version_no=1, status="draft",
            dsl_version="2.5", rule_dsl=VALID_DSL,
            dsl_hash=compute_dsl_hash(VALID_DSL), created_by="e2e_test",
        )
        session.add(version)
        session.flush()
        session.commit()

        cmd_svc = CommandBusService(session)
        cmd, _ = cmd_svc.enqueue(
            command_type="start_backtest",
            aggregate_type="strategy_version",
            aggregate_id=version.id,
            payload={
                "dsl": VALID_DSL,
                "strategy_version_id": str(version.id),
                "strategy_id": str(strategy.id),
                "timerange": "20240101-20240201",
                "initial_capital": 10000,
                "dsl_hash": compute_dsl_hash(VALID_DSL),
            },
            requested_by="e2e_test",
            idempotency_key=f"e2e-fail-{uuid.uuid4()}",
        )
        session.commit()

        # Mock a failed backtest
        from app.services.backtest_runner import BacktestResult, BacktestMetrics
        failed_result = BacktestResult(
            success=False,
            error_message="Freqtrade process timed out",
            exit_code=1,
        )

        with patch("app.workers.backtest_handler.FreqtradeBacktestRunner") as MockRunner:
            mock_instance = MockRunner.return_value
            mock_instance.run.return_value = failed_result

            worker = CommandWorker(session)
            worker.poll_once()

        # Command should be in retry_waiting (default max_retries=3)
        refreshed = session.get(CommandBusCommand, cmd.id)
        assert refreshed.status == CommandStatus.RETRY_WAITING.value
        assert refreshed.retry_count == 1
        assert refreshed.error_code == "HANDLER_ERROR"

        # Ledger should have failure events
        events = list(session.scalars(
            select(ExecutionLedgerEvent)
            .where(ExecutionLedgerEvent.command_id == cmd.id)
        ).all())
        event_types = [e.event_type for e in events]
        assert "FREQTRADE_BACKTEST_STARTED" in event_types
        assert "FREQTRADE_BACKTEST_FAILED" in event_types
        assert "PULSEDESK_COMMAND_FAILED" in event_types

    def test_idempotent_command_not_processed_twice(self, session: Session):
        """Same idempotency key → second enqueue returns existing, not a new command."""
        strategy = StrategyV2(
            name="Idemp Test", strategy_type="rule_dsl", source_type="manual", status="draft",
        )
        session.add(strategy)
        session.flush()

        version = StrategyVersion(
            strategy_id=strategy.id, version_no=1, status="draft",
            dsl_version="2.5", rule_dsl=VALID_DSL,
            dsl_hash=compute_dsl_hash(VALID_DSL), created_by="test",
        )
        session.add(version)
        session.flush()
        session.commit()

        cmd_svc = CommandBusService(session)
        idemp_key = f"e2e-idemp-{uuid.uuid4()}"

        cmd1, created1 = cmd_svc.enqueue(
            command_type="start_backtest",
            aggregate_type="strategy_version",
            aggregate_id=version.id,
            payload={"dsl": VALID_DSL, "strategy_version_id": str(version.id),
                     "strategy_id": str(strategy.id), "timerange": "20240101-20240201",
                     "initial_capital": 10000, "dsl_hash": "x"},
            requested_by="test",
            idempotency_key=idemp_key,
        )
        session.commit()
        assert created1 is True

        # Process it
        with patch("app.workers.backtest_handler.FreqtradeBacktestRunner") as MockRunner:
            MockRunner.return_value.run.return_value = _mock_backtest_result()
            CommandWorker(session).poll_once()

        assert session.get(CommandBusCommand, cmd1.id).status == CommandStatus.SUCCEEDED.value

        # Try to enqueue again with same key
        cmd2, created2 = cmd_svc.enqueue(
            command_type="start_backtest",
            aggregate_type="strategy_version",
            aggregate_id=version.id,
            payload={"dsl": VALID_DSL, "strategy_version_id": str(version.id),
                     "strategy_id": str(strategy.id), "timerange": "20240101-20240201",
                     "initial_capital": 10000, "dsl_hash": "x"},
            requested_by="test",
            idempotency_key=idemp_key,
        )
        session.commit()
        assert created2 is False
        assert cmd2.id == cmd1.id
        assert cmd2.status == CommandStatus.SUCCEEDED.value
