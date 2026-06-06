"""Unit tests for StartDryRunHandler and StopDryRunHandler."""
import uuid
from unittest.mock import patch

import pytest

from app.domain.command import CommandBusCommand
from app.domain.ledger import ExecutionLedgerEvent
from app.models.dryrun import DryRunRun
from app.services.dryrun_manager import DryRunStartResult
from app.workers.dryrun_handler import StartDryRunHandler, StopDryRunHandler


VALID_START_PAYLOAD = {
    "dsl": {
        "schema_version": "2.5", "timeframe": "1h", "symbols": ["BTC/USDT"],
        "entry": {"logic": "AND", "rules": [{"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": "<", "value": 30}]},
        "exit": {"logic": "OR", "rules": [{"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": ">", "value": 70}]},
        "filters": [], "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
        "risk": {"stoploss": -0.05, "max_open_trades": 3}, "metadata": {},
    },
    "dsl_hash": "abc123", "symbols": ["BTC/USDT"],
    "stake_amount": 100, "max_open_trades": 5, "initial_wallet": 10000,
    "exchange": "binance", "api_port": 8080, "strategy_id": 1,
}


def _make_start_command(session):
    cmd = CommandBusCommand(
        id=uuid.uuid4(), command_type="start_dryrun", aggregate_type="strategy_version",
        payload=VALID_START_PAYLOAD, status="running",
        idempotency_key=f"test-{uuid.uuid4()}", requested_by="test",
        timeout_sec=120, retry_count=0, max_retries=3,
    )
    session.add(cmd)
    session.flush()
    return cmd


def _make_stop_command(session, dryrun_run_id, reason="test"):
    cmd = CommandBusCommand(
        id=uuid.uuid4(), command_type="stop_dryrun", aggregate_type="dryrun_run",
        payload={"dryrun_run_id": dryrun_run_id, "reason": reason}, status="running",
        idempotency_key=f"test-{uuid.uuid4()}", requested_by="test",
        timeout_sec=60, retry_count=0, max_retries=3,
    )
    session.add(cmd)
    session.flush()
    return cmd


def _make_dryrun_run(session, status="running", pid=12345):
    run = DryRunRun(
        strategy_id=1, status=status, pid=pid,
        symbols=["BTC/USDT"], stake_amount=100, max_open_trades=5,
        initial_wallet=10000, exchange="binance",
    )
    session.add(run)
    session.flush()
    return run


@patch("app.workers.dryrun_handler.DryRunProcessManager")
def test_start_handler_success(mock_cls, session):
    mock_cls.return_value.start.return_value = DryRunStartResult(
        pid=12345, api_port=8080, api_url="http://127.0.0.1:8080",
        config_path="/tmp/cfg.json", rules_path="/tmp/rules.json",
    )

    cmd = _make_start_command(session)
    result = StartDryRunHandler().execute(cmd, session)

    run = session.query(DryRunRun).filter_by(command_id=str(cmd.id)).first()
    assert run is not None
    assert run.status == "running"
    assert run.pid == 12345

    evt = session.query(ExecutionLedgerEvent).filter_by(event_type="FREQTRADE_RUN_STARTED").first()
    assert evt is not None
    assert result["dryrun_run_id"] == run.id


@patch("app.workers.dryrun_handler.DryRunProcessManager")
def test_start_handler_failure(mock_cls, session):
    mock_cls.return_value.start.side_effect = RuntimeError("process failed")

    cmd = _make_start_command(session)
    with pytest.raises(RuntimeError):
        StartDryRunHandler().execute(cmd, session)

    run = session.query(DryRunRun).filter_by(command_id=str(cmd.id)).first()
    assert run is not None
    assert run.status == "failed"

    evt = session.query(ExecutionLedgerEvent).filter_by(event_type="FREQTRADE_RUN_STOPPED").first()
    assert evt is not None


@patch("app.workers.dryrun_handler.DryRunProcessManager")
def test_stop_handler_success(mock_cls, session):
    mock_cls.return_value.is_running.return_value = True
    mock_cls.return_value.stop.return_value = True

    run = _make_dryrun_run(session, status="running", pid=12345)
    cmd = _make_stop_command(session, dryrun_run_id=run.id)
    result = StopDryRunHandler().execute(cmd, session)

    session.refresh(run)
    assert run.status == "stopped"
    assert run.stopped_at is not None

    evt = session.query(ExecutionLedgerEvent).filter_by(event_type="FREQTRADE_RUN_STOPPED").first()
    assert evt is not None


@patch("app.workers.dryrun_handler.DryRunProcessManager")
def test_stop_handler_not_found(mock_cls, session):
    cmd = _make_stop_command(session, dryrun_run_id=999999)
    with pytest.raises(RuntimeError, match="not found"):
        StopDryRunHandler().execute(cmd, session)


@patch("app.workers.dryrun_handler.DryRunProcessManager")
def test_stop_handler_already_stopped(mock_cls, session):
    run = _make_dryrun_run(session, status="stopped", pid=12345)
    cmd = _make_stop_command(session, dryrun_run_id=run.id)
    result = StopDryRunHandler().execute(cmd, session)

    assert result.get("already_stopped") is True
    session.refresh(run)
    assert run.status == "stopped"
