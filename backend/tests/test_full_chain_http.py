"""Full HTTP chain: register/login -> strategy -> backtest -> worker -> ledger.

Freqtrade is mocked at the runner boundary; everything else (auth middleware,
routers, Command Bus, worker, ledger, readiness/risk) runs for real.
"""
from __future__ import annotations

import json

from app.config import settings
from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus
from app.domain.ledger import ExecutionLedgerEvent
from app.models.strategy import BacktestRun
from app.services.backtest_runner import BacktestMetrics, BacktestResult
from app.workers.command_worker import CommandWorker

VALID_DSL = {
    "schema_version": "2.5",
    "timeframe": "1h",
    "symbols": ["BTC/USDT"],
    "entry": {"logic": "AND", "rules": [{
        "type": "indicator_threshold", "indicator": "rsi",
        "params": {"period": 14}, "operator": "<", "value": 30,
    }]},
    "exit": {"logic": "OR", "rules": [{
        "type": "indicator_threshold", "indicator": "rsi",
        "params": {"period": 14}, "operator": ">", "value": 70,
    }]},
    "filters": [],
    "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
    "risk": {"stoploss": -0.05, "max_open_trades": 3},
    "metadata": {},
}


def _success_result() -> BacktestResult:
    return BacktestResult(
        success=True,
        metrics=BacktestMetrics(
            total_return_pct=8.5,
            sharpe_ratio=1.2,
            max_drawdown_pct=4.0,
            win_rate=0.55,
            profit_factor=1.4,
            total_trades=12,
        ),
        trades=[],
        equity_curve=[], 
    )


def test_full_chain_login_strategy_backtest(client, session, monkeypatch):
    monkeypatch.setattr(settings, "auth_required", True)

    # Public registration bootstraps the superuser; login returns a token.
    reg = client.post("/auth/register", json={
        "username": "e2e", "email": "e2e@example.com", "password": "secret123",
    })
    assert reg.status_code == 201
    login = client.post("/auth/login", data={
        "username": "e2e@example.com", "password": "secret123",
    })
    assert login.status_code == 200
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Every protected endpoint now needs the token.
    assert client.get("/api/overview/dashboard").status_code == 401

    dashboard = client.get("/api/overview/dashboard", headers=headers)
    assert dashboard.status_code == 200

    strategy = client.post("/api/v2/strategies", json={
        "name": "HTTP E2E", "strategy_type": "rule_dsl", "source_type": "manual",
    }, headers=headers)
    assert strategy.status_code == 201
    strategy_id = strategy.json()["id"]

    version = client.post(
        f"/api/v2/strategies/{strategy_id}/versions",
        json={"rule_dsl": VALID_DSL},
        headers=headers,
    )
    assert version.status_code == 201
    version_id = version.json()["id"]

    started = client.post("/api/v2/backtest", json={
        "dsl": VALID_DSL,
        "timerange": "20240101-20240601",
        "symbols": ["BTC/USDT"],
        "initial_capital": 10000,
        "strategy_id": 0,
        "strategy_version_id": version_id,
        "client_request_id": "e2e-1",
    }, headers=headers)
    assert started.status_code == 202
    command_id = started.json()["command_id"]

    # Worker executes the enqueued command with a deterministic backtest result.
    from unittest.mock import patch

    with patch("app.workers.backtest_handler.FreqtradeBacktestRunner") as runner_cls:
        runner_cls.return_value.run.return_value = _success_result()
        worker = CommandWorker(session)
        assert worker.poll_once() is True
        session.commit()

    session.expire_all()
    cmd = session.get(CommandBusCommand, __import__("uuid").UUID(command_id))
    assert cmd is not None
    assert cmd.status == CommandStatus.SUCCEEDED.value, cmd.error_message

    events = session.query(ExecutionLedgerEvent).filter(
        ExecutionLedgerEvent.command_id == cmd.id
    ).all()
    assert {e.event_type for e in events} >= {
        "PULSEDESK_COMMAND_STARTED",
        "FREQTRADE_BACKTEST_STARTED",
        "PULSEDESK_COMMAND_SUCCEEDED",
    }

    run = session.query(BacktestRun).filter(BacktestRun.command_id == str(cmd.id)).first()
    assert run is not None
    assert run.status == "completed"
    assert run.total_trades == 12
    assert json.loads(json.dumps(run.result))["metrics"]["total_return"] == 8.5

    status = client.get(f"/api/v2/backtest/status/{command_id}", headers=headers)
    assert status.status_code == 200

    # Manual block is enforced and visible to readiness.
    blocked = client.post("/api/risk/block-new-entries", json={"reason": "e2e"},
                          headers=headers)
    assert blocked.status_code == 200
    readiness = client.get("/api/overview/live-readiness", headers=headers)
    assert readiness.status_code == 200
    codes = {b["code"] for b in readiness.json()["blocking_reasons"]}
    assert "risk_locked" in codes

    client.post("/api/risk/unblock", headers=headers)
