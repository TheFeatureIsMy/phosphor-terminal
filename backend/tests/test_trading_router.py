"""Trading control router tests — start-paper / start-live-small / disable-auto,
strategy-run lifecycle (pause/resume/stop), stop-protection action endpoints.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.config import settings
from app.domain.command import CommandBusCommand
from app.domain.execution import StrategyRun
from app.domain.risk import (
    CapitalPool,
    RiskPolicy,
    RiskPolicyVersion,
    StrategyRiskPolicyBinding,
)
from app.domain.strategy import StrategyV2, StrategyVersion
from app.models.dryrun import DryRunRun
from app.models.strategy import BacktestRun
from app.services.account_risk_firewall import AccountRiskFirewall


def _utcnow_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _sample_dsl() -> dict:
    return {
        "schema_version": "2.5",
        "timeframe": "1d",
        "symbols": ["BTC/USDT"],
        "entry": {
            "logic": "AND",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "operator": "<",
                 "value": 30, "params": {"period": 14}},
            ],
        },
        "exit": {
            "logic": "OR",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "operator": ">",
                 "value": 70, "params": {"period": 14}},
            ],
        },
        "filters": [],
        "position_sizing": {"position_pct": 0.05},
        "risk": {
            "stoploss": -0.05,
            "max_open_trades": 3,
            "trailing_stop": False,
        },
    }


def _create_version(session, status: str = "paper_passed", dsl: dict | None = None) -> StrategyVersion:
    strategy = StrategyV2(
        name="test-strategy", strategy_type="dsl", source_type="manual", status="active",
    )
    session.add(strategy)
    session.flush()

    version = StrategyVersion(
        strategy_id=strategy.id,
        version_no=1,
        status=status,
        dsl_version="2.5",
        rule_dsl=dsl if dsl is not None else _sample_dsl(),
        dsl_hash="test-hash",
        created_by="test",
    )
    session.add(version)
    session.flush()
    return version


def _seed_live_small_ready(session) -> tuple[StrategyVersion, CapitalPool]:
    """Seed a version that passes all 7 live_small preconditions."""
    version = _create_version(session, status="paper_passed")
    vid_str = str(version.id)

    # Backtest record (>=1 required)
    session.add(BacktestRun(
        strategy_id=0,
        strategy_version_id=vid_str,
        status="completed",
        start_date="20260101",
        end_date="20260201",
        initial_capital=10000,
    ))

    # Dry-run record with >=72h duration and no failure
    now = _utcnow_naive()
    session.add(DryRunRun(
        strategy_id=0,
        strategy_version_id=vid_str,
        status="completed",
        started_at=now - timedelta(hours=100),
        stopped_at=now - timedelta(hours=1),
    ))

    # Capital pool + risk policy binding (live_small mode)
    pool = CapitalPool(
        name="small-pool", pool_type="live_small", currency="USDT",
        total_budget=500.0,
        max_position_pct_per_trade=0.03,
        max_total_exposure_pct=0.30,
        max_daily_loss_pct=0.03,
        max_drawdown_pct=0.08,
        requires_human_confirm=True,
    )
    session.add(pool)
    session.flush()

    policy = RiskPolicy(name="p", policy_type="global", status="active")
    session.add(policy)
    session.flush()
    policy_version = RiskPolicyVersion(
        risk_policy_id=policy.id, version_no=1,
        policy_json={}, policy_hash="h", status="active", created_by="test",
    )
    session.add(policy_version)
    session.flush()

    session.add(StrategyRiskPolicyBinding(
        strategy_version_id=version.id,
        risk_policy_version_id=policy_version.id,
        capital_pool_id=pool.id,
        mode="live_small",
    ))
    session.commit()
    return version, pool


@pytest.fixture(autouse=True)
def _reset_firewall():
    yield
    AccountRiskFirewall.deactivate_manual_block()


# ══════════════════════════════════════════════════════════════════════
# POST /api/trading/start-paper
# ══════════════════════════════════════════════════════════════════════

class TestStartPaper:
    def test_missing_version_404(self, client, session):
        r = client.post("/api/trading/start-paper", json={
            "strategy_version_id": str(uuid.uuid4()),
        })
        assert r.status_code == 404

    def test_invalid_dsl_rejected(self, client, session):
        dsl = _sample_dsl()
        del dsl["risk"]["stoploss"]
        version = _create_version(session, dsl=dsl)
        session.commit()
        r = client.post("/api/trading/start-paper", json={
            "strategy_version_id": str(version.id),
        })
        assert r.status_code == 422
        assert r.json()["detail"]["state"] == "blocked"

    def test_enqueues_paper_dryrun_command(self, client, session):
        version = _create_version(session)
        session.commit()
        r = client.post("/api/trading/start-paper", json={
            "strategy_version_id": str(version.id),
            "symbols": ["BTC/USDT"],
        })
        assert r.status_code == 202
        body = r.json()
        assert body["state"] == "running"
        assert body["command_id"]

        cmd = session.get(CommandBusCommand, uuid.UUID(body["command_id"]))
        assert cmd.command_type == "start_dryrun"
        assert cmd.payload["mode"] == "paper"
        assert cmd.payload["strategy_version_id"] == str(version.id)


# ══════════════════════════════════════════════════════════════════════
# POST /api/trading/start-live-small — gate chain
# ══════════════════════════════════════════════════════════════════════

class TestStartLiveSmallGates:
    def test_preconditions_failed_blocked(self, client, session):
        # Fresh draft version, no run history → preconditions fail
        version = _create_version(session, status="draft")
        pool = CapitalPool(
            name="p", pool_type="live_small", currency="USDT",
            total_budget=500.0, max_position_pct_per_trade=0.03,
            max_total_exposure_pct=0.30, max_daily_loss_pct=0.03,
            max_drawdown_pct=0.08,
        )
        session.add(pool)
        session.commit()
        r = client.post("/api/trading/start-live-small", json={
            "strategy_version_id": str(version.id),
            "capital_pool_id": str(pool.id),
            "human_confirmed": True,
            "confirmed_by": "tester",
        })
        assert r.status_code == 200
        body = r.json()
        assert body["state"] == "blocked"
        assert "strategy_version_status" in body["reason_codes"]
        assert body["can_proceed"] is False

    def test_requires_human_confirmation(self, client, session):
        version, pool = _seed_live_small_ready(session)
        r = client.post("/api/trading/start-live-small", json={
            "strategy_version_id": str(version.id),
            "capital_pool_id": str(pool.id),
            "human_confirmed": False,
        })
        body = r.json()
        assert body["state"] == "waiting_confirmation"
        assert body["reason_codes"] == ["human_confirmation_required"]
        assert body["can_proceed"] is True

    def test_not_enabled_by_default(self, client, session):
        version, pool = _seed_live_small_ready(session)
        assert settings.live_small_enabled is False
        r = client.post("/api/trading/start-live-small", json={
            "strategy_version_id": str(version.id),
            "capital_pool_id": str(pool.id),
            "human_confirmed": True,
            "confirmed_by": "tester",
        })
        body = r.json()
        assert body["state"] == "not_enabled"
        assert body["reason_codes"] == ["live_small_execution_not_enabled"]

    def test_blocked_when_version_not_transitionable(self, client, session, monkeypatch):
        version, pool = _seed_live_small_ready(session)
        # Force a status that passes nothing downstream but differs from
        # paper_passed/live_pending after gates — simulate via archived version
        # re-seeded directly.
        version.status = "archived"
        session.commit()
        monkeypatch.setattr(settings, "live_small_enabled", True)
        r = client.post("/api/trading/start-live-small", json={
            "strategy_version_id": str(version.id),
            "capital_pool_id": str(pool.id),
            "human_confirmed": True,
            "confirmed_by": "tester",
        })
        # archived fails preconditions (status gate) → blocked
        assert r.json()["state"] == "blocked"

    def test_approved_enqueues_request_live_small(self, client, session, monkeypatch):
        version, pool = _seed_live_small_ready(session)
        monkeypatch.setattr(settings, "live_small_enabled", True)
        r = client.post("/api/trading/start-live-small", json={
            "strategy_version_id": str(version.id),
            "capital_pool_id": str(pool.id),
            "human_confirmed": True,
            "confirmed_by": "tester",
        })
        body = r.json()
        assert body["state"] == "approved_enqueued", body["reason_codes"]
        assert body["command_id"]

        cmd = session.get(CommandBusCommand, uuid.UUID(body["command_id"]))
        assert cmd.command_type == "request_live_small"
        assert cmd.payload["confirmed_by"] == "tester"

        # Version promoted paper_passed → live_pending for the handler
        session.refresh(version)
        assert version.status == "live_pending"


# ══════════════════════════════════════════════════════════════════════
# POST /api/trading/disable-auto
# ══════════════════════════════════════════════════════════════════════

class TestDisableAuto:
    def test_stops_active_dryruns_and_blocks(self, client, session):
        session.add(DryRunRun(strategy_id=0, status="running"))
        session.add(DryRunRun(strategy_id=0, status="starting"))
        session.add(DryRunRun(strategy_id=0, status="stopped"))
        session.commit()

        r = client.post("/api/trading/disable-auto", json={"reason": "test-disable"})
        assert r.status_code == 200
        body = r.json()
        assert body["state"] == "blocked"
        assert body["stopped_dryruns"] == 2
        assert body["firewall_active"] is True
        assert len(body["command_ids"]) == 2

        cmd = session.get(CommandBusCommand, uuid.UUID(body["command_ids"][0]))
        assert cmd.command_type == "stop_dryrun"

    def test_no_active_runs(self, client, session):
        r = client.post("/api/trading/disable-auto", json={})
        body = r.json()
        assert body["stopped_dryruns"] == 0
        assert body["firewall_active"] is True


# ══════════════════════════════════════════════════════════════════════
# Strategy run lifecycle — pause / resume / stop
# ══════════════════════════════════════════════════════════════════════

class TestRunLifecycle:
    def _make_run(self, session) -> StrategyRun:
        version = _create_version(session)
        run = StrategyRun(
            strategy_version_id=version.id, mode="dry_run", status="running",
        )
        session.add(run)
        session.commit()
        return run

    def test_pause_enqueues_command(self, client, session):
        run = self._make_run(session)
        r = client.post(f"/api/v2/strategy-runs/{run.id}/pause", json={"reason": "test"})
        assert r.status_code == 200
        body = r.json()
        assert body["state"] == "running"
        cmd = session.get(CommandBusCommand, uuid.UUID(body["command_id"]))
        assert cmd.command_type == "pause_strategy"
        assert cmd.aggregate_id == run.id

    def test_resume_enqueues_command(self, client, session):
        run = self._make_run(session)
        run.status = "stopped"
        session.commit()
        r = client.post(f"/api/v2/strategy-runs/{run.id}/resume", json={})
        assert r.status_code == 200
        cmd = session.get(CommandBusCommand, uuid.UUID(r.json()["command_id"]))
        assert cmd.command_type == "resume_strategy"

    def test_stop_enqueues_pause_and_dryrun_stops(self, client, session):
        run = self._make_run(session)
        session.add(DryRunRun(
            strategy_id=0,
            strategy_version_id=str(run.strategy_version_id),
            status="running",
        ))
        session.commit()
        r = client.post(f"/api/v2/strategy-runs/{run.id}/stop", json={"reason": "halt"})
        assert r.status_code == 200
        body = r.json()
        assert body["stopped_dryruns"] == 1
        types = {c.command_type for c in session.query(CommandBusCommand).all()}
        assert types == {"pause_strategy", "stop_dryrun"}

    def test_pause_missing_run_404(self, client, session):
        r = client.post(f"/api/v2/strategy-runs/{uuid.uuid4()}/pause", json={})
        assert r.status_code == 404

    def test_run_detail_execution_summary(self, client, session):
        from app.domain.ledger import ExecutionLedgerEvent
        from app.domain.order import ExecutionOrder, ExecutionPosition
        from app.repositories.ledger_repository import LedgerRepository

        run = self._make_run(session)
        now = _utcnow_naive()

        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(), event_time=now, event_type="ORDER_OPENED",
            source_system="pulsedesk", source_event_id="e1",
            event_hash=LedgerRepository.compute_event_hash("pulsedesk", "e1", "ORDER_OPENED", {}, now),
            strategy_run_id=run.id, normalized_payload={},
        )
        session.add(evt)
        session.flush()

        session.add(ExecutionOrder(
            latest_ledger_event_id=evt.id, strategy_run_id=run.id,
            source_system="pulsedesk", source_order_id="o1",
            exchange="binance", symbol="BTC/USDT", side="buy", status="open",
        ))
        session.add(ExecutionOrder(
            latest_ledger_event_id=evt.id, strategy_run_id=run.id,
            source_system="pulsedesk", source_order_id="o2",
            exchange="binance", symbol="ETH/USDT", side="buy", status="pending",
        ))
        session.add(ExecutionPosition(
            latest_ledger_event_id=evt.id, strategy_run_id=run.id,
            exchange="binance", symbol="BTC/USDT", status="open",
        ))
        session.commit()

        r = client.get(f"/api/v2/strategy-runs/{run.id}")
        assert r.status_code == 200
        ex = r.json()["execution"]
        assert ex["orders_total"] == 2
        assert ex["orders_open"] == 1
        assert ex["orders_pending"] == 1
        assert ex["positions_open"] == 1
        assert ex["last_ledger_event_at"]


# ══════════════════════════════════════════════════════════════════════
# Stop protection action endpoints
# ══════════════════════════════════════════════════════════════════════

class TestStopProtectionActions:
    def test_refresh_unknown_position_404(self, client, session):
        # No Freqtrade DB available in tests → no positions → not found
        r = client.post("/api/risk/stop-protection/unknown-id/refresh")
        assert r.status_code == 404
        assert r.json()["reason_codes"] == ["position_not_found"]

    def test_force_lock_unknown_position_404(self, client, session):
        r = client.post("/api/risk/stop-protection/unknown-id/force-lock")
        assert r.status_code == 404
        assert r.json()["reason_codes"] == ["position_not_found"]

    def test_release_lock_unknown_position_404(self, client, session):
        r = client.post("/api/risk/stop-protection/unknown-id/release-lock")
        assert r.status_code == 404

    def test_exchange_protive_stops_unavailable_graceful(self, client, session):
        # Freqtrade not running in tests → data_source_unavailable, no 500
        r = client.get("/api/risk/exchange-protective-stops")
        assert r.status_code == 200
        assert r.json()["state"] == "data_source_unavailable"
        assert r.json()["stops"] == []

    def test_volatility_locks_endpoint_shape(self, client, session):
        r = client.get("/api/risk/volatility-locks")
        assert r.status_code == 200
        body = r.json()
        assert "locks" in body and "state" in body
