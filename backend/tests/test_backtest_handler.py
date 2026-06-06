"""Unit tests for StartBacktestHandler."""

import uuid
from datetime import datetime, timezone
from unittest.mock import patch

import pytest

from app.workers.backtest_handler import StartBacktestHandler
from app.domain.command import CommandBusCommand
from app.models.strategy import BacktestRun
from app.domain.ledger import ExecutionLedgerEvent
from app.services.backtest_runner import BacktestResult, BacktestMetrics


VALID_PAYLOAD = {
    "dsl": {
        "schema_version": "2.5",
        "timeframe": "1h",
        "symbols": ["BTC/USDT"],
        "entry": {
            "logic": "AND",
            "rules": [
                {
                    "type": "indicator_threshold",
                    "indicator": "rsi",
                    "params": {"period": 14},
                    "operator": "<",
                    "value": 30,
                }
            ],
        },
        "exit": {
            "logic": "OR",
            "rules": [
                {
                    "type": "indicator_threshold",
                    "indicator": "rsi",
                    "params": {"period": 14},
                    "operator": ">",
                    "value": 70,
                }
            ],
        },
        "filters": [],
        "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
        "risk": {"stoploss": -0.05, "max_open_trades": 3},
        "metadata": {},
    },
    "dsl_hash": "abc123",
    "timerange": "20250101-20250601",
    "symbols": ["BTC/USDT"],
    "initial_capital": 10000,
    "stake_amount": 100,
    "max_open_trades": 5,
    "exchange": "binance",
    "strategy_id": 1,
}


def _make_command(session, payload=None):
    cmd = CommandBusCommand(
        id=uuid.uuid4(),
        command_type="start_backtest",
        aggregate_type="strategy_version",
        payload=payload or VALID_PAYLOAD,
        status="running",
        idempotency_key=f"test-{uuid.uuid4()}",
        requested_by="test",
        timeout_sec=600,
        retry_count=0,
        max_retries=3,
    )
    session.add(cmd)
    session.flush()
    return cmd


def _success_metrics():
    return BacktestMetrics(
        sharpe_ratio=1.85,
        win_rate=0.62,
        max_drawdown_pct=8.0,
        total_trades=47,
        profit_factor=2.1,
        total_return_pct=18.3,
    )


def _success_result(metrics=None):
    return BacktestResult(
        success=True,
        metrics=metrics or _success_metrics(),
    )


def _failure_result(error_msg="Insufficient data for BTC/USDT"):
    return BacktestResult(
        success=False,
        error_message=error_msg,
        exit_code=1,
    )


@patch("app.workers.backtest_handler.FreqtradeBacktestRunner")
def test_handler_success(mock_runner_cls, session):
    metrics = _success_metrics()
    mock_runner_cls.return_value.run.return_value = _success_result(metrics)

    cmd = _make_command(session)
    handler = StartBacktestHandler()
    result = handler.execute(cmd, session)

    bt_run = session.query(BacktestRun).filter_by(command_id=str(cmd.id)).one()
    assert bt_run.status == "completed"
    assert bt_run.sharpe_ratio == pytest.approx(1.85)
    assert bt_run.win_rate == pytest.approx(0.62)

    events = (
        session.query(ExecutionLedgerEvent)
        .filter_by(command_id=cmd.id)
        .order_by(ExecutionLedgerEvent.event_time)
        .all()
    )
    event_types = [e.event_type for e in events]
    assert "FREQTRADE_BACKTEST_STARTED" in event_types
    assert "FREQTRADE_BACKTEST_COMPLETED" in event_types

    assert "backtest_run_id" in result
    assert result["backtest_run_id"] == bt_run.id


@patch("app.workers.backtest_handler.FreqtradeBacktestRunner")
def test_handler_failure_raises(mock_runner_cls, session):
    error_msg = "Insufficient data for BTC/USDT"
    mock_runner_cls.return_value.run.return_value = _failure_result(error_msg)

    cmd = _make_command(session)
    handler = StartBacktestHandler()

    with pytest.raises(RuntimeError):
        handler.execute(cmd, session)

    bt_run = session.query(BacktestRun).filter_by(command_id=str(cmd.id)).one()
    assert bt_run.status == "failed"
    assert error_msg in (bt_run.error_message or "")

    events = (
        session.query(ExecutionLedgerEvent)
        .filter_by(command_id=cmd.id)
        .all()
    )
    event_types = [e.event_type for e in events]
    assert "FREQTRADE_BACKTEST_FAILED" in event_types


@patch("app.workers.backtest_handler.FreqtradeBacktestRunner")
def test_handler_creates_backtest_run(mock_runner_cls, session):
    mock_runner_cls.return_value.run.return_value = _success_result()

    cmd = _make_command(session)
    handler = StartBacktestHandler()
    handler.execute(cmd, session)

    bt_run = session.query(BacktestRun).filter_by(command_id=str(cmd.id)).one()

    assert bt_run.command_id == str(cmd.id)
    assert bt_run.symbols == ["BTC/USDT"]
    assert bt_run.start_date == "2025-01-01"
    assert bt_run.end_date == "2025-06-01"
