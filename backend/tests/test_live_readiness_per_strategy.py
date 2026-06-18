"""Tests for PerStrategyReadiness — 6 strategy gates + 5 system gates + grand_status + next_action.

17+ test cases covering:
- 6 strategy gates: validation, backtest, dryrun, risk_config, capital, strategy
- Grand status: not_live, needs_config, needs_validation, paper_passed, ready_for_live
- Next action: first-failed gate, bind_live_small, approve_live
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.domain.enums import StrategyVersionStatus, StrategyRunMode, StrategyRunStatus, CapitalPoolType
from app.domain.execution import StrategyRun
from app.domain.risk import CapitalPool, StrategyRiskPolicyBinding
from app.domain.strategy import StrategyV2, StrategyVersion
from app.schemas.per_strategy_readiness import (
    PerStrategyReadinessResponse,
    ReadinessGate,
    ReadinessNextAction,
)
from app.services.dsl_hasher import compute_dsl_hash
from app.services.live_readiness_service import LiveReadinessService


# ══════════════════════════════════════════════════════════════════════
# Fixtures
# ══════════════════════════════════════════════════════════════════════


@pytest.fixture
def db_session(session):
    return session


@pytest.fixture
def svc():
    """LiveReadinessService instance — evaluate is monkeypatched in tests that need it."""
    return LiveReadinessService()


@pytest.fixture
def healthy_system_gates():
    """Default healthy system gates for tests that don't need to vary them."""
    return [
        ReadinessGate(key="mode", status="healthy", value="live_small", threshold="paper|live_small|live_full"),
        ReadinessGate(key="exchange", status="healthy", value="BINANCE", threshold="connected"),
        ReadinessGate(key="data_source", status="healthy", value="online", threshold="online"),
        ReadinessGate(key="notification", status="healthy", value="configured", threshold="optional"),
        ReadinessGate(key="emergency_stop", status="healthy", value="available", threshold="available"),
    ]


def _make_strategy(db, status: str = "draft") -> StrategyV2:
    s = StrategyV2(name="test-s", strategy_type="rule_dsl", source_type="manual", status=status)
    db.add(s)
    db.flush()
    return s


def _make_version(
    db, strategy_id: uuid.UUID,
    version_no: int = 1,
    status: str = "draft",
) -> StrategyVersion:
    v = StrategyVersion(
        strategy_id=strategy_id, version_no=version_no, status=status,
        dsl_version="2.5", rule_dsl={"schema_version": "2.5"},
        dsl_hash=compute_dsl_hash({"schema_version": "2.5"}), created_by="test",
    )
    db.add(v)
    db.flush()
    return v


def _make_backtest(db, strategy_uuid: uuid.UUID, status: str = "completed") -> None:
    from app.models.strategy import BacktestRun
    b = BacktestRun(
        strategy_id=1,
        strategy_uuid=strategy_uuid,
        status=status,
        start_date="2026-01-01",
        end_date="2026-06-01",
        initial_capital=10000,
        symbols=["BTC/USDT"],
    )
    db.add(b)
    db.flush()


def _make_dryrun(
    db, version_id: uuid.UUID,
    mode: str = "dry_run",
    status: str = "stopped",
    started_at: datetime | None = None,
    stopped_at: datetime | None = None,
) -> StrategyRun:
    now = datetime.now(timezone.utc)
    sr = StrategyRun(
        strategy_version_id=version_id,
        mode=mode,
        status=status,
        started_at=started_at or (now - timedelta(hours=100)),
        stopped_at=stopped_at or now,
    )
    db.add(sr)
    db.flush()
    return sr


def _make_live_small_run(db, version_id: uuid.UUID, status: str = "running") -> StrategyRun:
    now = datetime.now(timezone.utc)
    sr = StrategyRun(
        strategy_version_id=version_id,
        mode="live_small",
        status=status,
        started_at=now - timedelta(hours=2),
    )
    db.add(sr)
    db.flush()
    return sr


def _make_binding(
    db, version_id: uuid.UUID, pool_id: uuid.UUID,
    rpv_id: uuid.UUID | None = None, mode: str = "live_small",
) -> StrategyRiskPolicyBinding:
    if rpv_id is None:
        from app.domain.risk import RiskPolicy, RiskPolicyVersion
        rp = RiskPolicy(name="cp", policy_type="conservative", status="active")
        db.add(rp)
        db.flush()
        rpv = RiskPolicyVersion(
            risk_policy_id=rp.id, version_no=1,
            policy_json={"max_position_pct": 0.02},
            policy_hash="abc", status="active", created_by="u",
        )
        db.add(rpv)
        db.flush()
        rpv_id = rpv.id
    b = StrategyRiskPolicyBinding(
        strategy_version_id=version_id,
        risk_policy_version_id=rpv_id,
        capital_pool_id=pool_id,
        mode=mode,
    )
    db.add(b)
    db.flush()
    return b


def _make_live_small_pool(db, total_budget: float = 5000) -> CapitalPool:
    cp = CapitalPool(
        name="ls-pool", pool_type="live_small", currency="USDT",
        total_budget=total_budget, max_position_pct_per_trade=0.02,
        max_total_exposure_pct=0.5, max_daily_loss_pct=0.05, max_drawdown_pct=0.15,
    )
    db.add(cp)
    db.flush()
    return cp


def _call(svc, strategy_id, db, system_gates=None):
    """Helper to call compute_for_strategy with optional system_gates injection."""
    return svc.compute_for_strategy(
        strategy_id=strategy_id,
        db=db,
        system_gates=system_gates,
    )


# ══════════════════════════════════════════════════════════════════════
# Strategy Gate Tests
# ══════════════════════════════════════════════════════════════════════


class TestValidationGate:
    def test_healthy_when_latest_version_validated(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session, status="draft")
        _make_version(db_session, s.id, status="validated")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "validation")
        assert gate.status == "healthy"

    def test_healthy_when_latest_version_backtested(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="backtested")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "validation")
        assert gate.status == "healthy"

    def test_healthy_when_latest_version_paper_running(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="paper_running")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "validation")
        assert gate.status == "healthy"

    def test_healthy_when_latest_version_paper_passed(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="paper_passed")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "validation")
        assert gate.status == "healthy"

    def test_healthy_when_latest_version_live_pending(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="live_pending")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "validation")
        assert gate.status == "healthy"

    def test_failed_when_latest_version_draft(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="draft")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "validation")
        assert gate.status == "failed"

    def test_failed_when_latest_version_rejected(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="rejected")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "validation")
        assert gate.status == "failed"

    def test_failed_when_no_version(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "validation")
        assert gate.status == "failed"
        assert "no version" in gate.detail.lower()


class TestBacktestGate:
    def test_healthy_when_completed_backtest_exists(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="validated")
        _make_backtest(db_session, s.id, status="completed")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "backtest")
        assert gate.status == "healthy"

    def test_failed_when_no_backtest(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="validated")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "backtest")
        assert gate.status == "failed"


class TestDryrunGate:
    def test_healthy_when_72h_paper_passed(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="paper_passed")
        now = datetime.now(timezone.utc)
        _make_dryrun(db_session, v.id, started_at=now - timedelta(hours=100), stopped_at=now)
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "dryrun")
        assert gate.status == "healthy"

    def test_warning_when_running_under_72h(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="paper_running")
        now = datetime.now(timezone.utc)
        _make_dryrun(db_session, v.id, mode="dry_run", status="running",
                      started_at=now - timedelta(hours=10), stopped_at=None)
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "dryrun")
        assert gate.status == "warning"

    def test_failed_when_under_72h(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="validated")
        now = datetime.now(timezone.utc)
        _make_dryrun(db_session, v.id, started_at=now - timedelta(hours=10), stopped_at=now)
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "dryrun")
        assert gate.status == "failed"

    def test_failed_when_no_run(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="validated")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "dryrun")
        assert gate.status == "failed"

    def test_dryrun_gate_handles_timezone_aware_datetimes(self, db_session, svc, healthy_system_gates):
        """Regression: timezone-aware started_at must not raise TypeError (Fix 1)."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="paper_running")
        _make_dryrun(db_session, v.id, mode="dry_run", status="running",
                      started_at=datetime.now(timezone.utc) - timedelta(hours=10),
                      stopped_at=None)
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "dryrun")
        # Running under 72h with tz-aware started_at should produce warning (not crash)
        assert gate.status == "warning"

    def test_dryrun_gate_failed_when_running_without_started_at(self, db_session, svc, healthy_system_gates):
        """Running/starting run with None started_at should be failed, not warning (Fix 3)."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="draft")
        # Create a run directly to bypass _make_dryrun's fallback defaults
        sr = StrategyRun(
            strategy_version_id=v.id,
            mode="dry_run",
            status="running",
            started_at=None,
            stopped_at=None,
        )
        db_session.add(sr)
        db_session.flush()
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "dryrun")
        assert gate.status == "failed"
        assert "dryrun_no_start_time" in (gate.reason_codes or [])


class TestRiskConfigGate:
    def test_healthy_when_live_small_binding_exists(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="paper_passed")
        pool = _make_live_small_pool(db_session)
        _make_binding(db_session, v.id, pool.id, mode="live_small")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "risk_config")
        assert gate.status == "healthy"

    def test_failed_when_no_binding(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="validated")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "risk_config")
        assert gate.status == "failed"


class TestCapitalGate:
    def test_healthy_when_live_small_pool_exists(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="validated")
        _make_live_small_pool(db_session, total_budget=5000)
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "capital")
        assert gate.status == "healthy"

    def test_failed_when_no_live_small_pool(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="validated")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "capital")
        assert gate.status == "failed"


class TestStrategyGate:
    def test_healthy_when_strategy_active(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session, status="active")
        _make_version(db_session, s.id, status="validated")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "strategy")
        assert gate.status == "healthy"

    def test_failed_when_strategy_archived(self, db_session, svc, healthy_system_gates):
        s = _make_strategy(db_session, status="archived")
        _make_version(db_session, s.id, status="archived")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        gate = _gate_by_key(result.strategy_gates, "strategy")
        assert gate.status == "failed"


# ══════════════════════════════════════════════════════════════════════
# Grand Status Tests
# ══════════════════════════════════════════════════════════════════════


class TestGrandStatus:
    def test_not_live_when_system_gate_fails(self, db_session, svc):
        """Any system gate failed → not_live, regardless of strategy gates."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="paper_passed")
        now = datetime.now(timezone.utc)
        _make_dryrun(db_session, v.id, started_at=now - timedelta(hours=100), stopped_at=now)
        system = [
            ReadinessGate(key="mode", status="healthy"),
            ReadinessGate(key="exchange", status="failed", detail="exchange unreachable"),
            ReadinessGate(key="data_source", status="healthy"),
            ReadinessGate(key="notification", status="healthy"),
            ReadinessGate(key="emergency_stop", status="healthy"),
        ]
        result = _call(svc, s.id, db_session, system)
        assert result.grand_status == "not_live"

    def test_needs_config_when_capital_or_risk_missing(self, db_session, svc, healthy_system_gates):
        """Missing capital pool → needs_config."""
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="validated")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.grand_status == "needs_config"

    def test_needs_config_when_risk_missing(self, db_session, svc, healthy_system_gates):
        """Missing risk_config → needs_config."""
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="validated")
        _make_live_small_pool(db_session)
        # no binding → risk_config fails → needs_config
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.grand_status == "needs_config"

    def test_needs_validation_when_validation_missing(self, db_session, svc, healthy_system_gates):
        """Draft version → validation fails → needs_validation."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="draft")
        pool = _make_live_small_pool(db_session)
        _make_binding(db_session, v.id, pool.id, mode="live_small")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.grand_status == "needs_validation"

    def test_needs_validation_when_backtest_missing(self, db_session, svc, healthy_system_gates):
        """No backtest → needs_validation."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="validated")
        pool = _make_live_small_pool(db_session)
        _make_binding(db_session, v.id, pool.id, mode="live_small")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.grand_status == "needs_validation"

    def test_needs_validation_when_dryrun_missing(self, db_session, svc, healthy_system_gates):
        """No dryrun → needs_validation."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="paper_passed")
        _make_backtest(db_session, s.id, status="completed")
        pool = _make_live_small_pool(db_session)
        _make_binding(db_session, v.id, pool.id, mode="live_small")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.grand_status == "needs_validation"

    def test_paper_passed_when_dryrun_passed_but_not_live(self, db_session, svc, healthy_system_gates):
        """All gates pass + dryrun 72h+ completed → paper_passed."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="paper_passed")
        now = datetime.now(timezone.utc)
        _make_dryrun(db_session, v.id, started_at=now - timedelta(hours=100), stopped_at=now)
        _make_backtest(db_session, s.id, status="completed")
        pool = _make_live_small_pool(db_session)
        _make_binding(db_session, v.id, pool.id, mode="live_small")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.grand_status == "paper_passed"

    def test_ready_for_live_when_all_gates_pass(self, db_session, svc, healthy_system_gates):
        """All gates pass + live_small run exists → ready_for_live."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="live_small")
        now = datetime.now(timezone.utc)
        _make_dryrun(db_session, v.id, started_at=now - timedelta(hours=100), stopped_at=now)
        _make_backtest(db_session, s.id, status="completed")
        pool = _make_live_small_pool(db_session)
        _make_binding(db_session, v.id, pool.id, mode="live_small")
        _make_live_small_run(db_session, v.id, status="running")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.grand_status == "ready_for_live"


# ══════════════════════════════════════════════════════════════════════
# Next Action Tests
# ══════════════════════════════════════════════════════════════════════


class TestNextAction:
    def test_first_failed_strategy_gate_decides(self, db_session, svc, healthy_system_gates):
        """First non-healthy gate (validation) sets next_action.code."""
        s = _make_strategy(db_session)
        _make_version(db_session, s.id, status="draft")  # validation fails
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.next_action.code == "validation"

    def test_backtest_gate_decides_when_validation_passes(self, db_session, svc, healthy_system_gates):
        """Second gate (backtest) determines next_action when validation is healthy."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="validated")  # validation ok
        pool = _make_live_small_pool(db_session)
        _make_binding(db_session, v.id, pool.id, mode="live_small")
        # no backtest → backtest fails
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.next_action.code == "backtest"

    def test_paper_passed_suggests_bind_live_small(self, db_session, svc, healthy_system_gates):
        """All gates pass + paper_passed → next_action.code = bind_live_small."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="paper_passed")
        now = datetime.now(timezone.utc)
        _make_dryrun(db_session, v.id, started_at=now - timedelta(hours=100), stopped_at=now)
        _make_backtest(db_session, s.id, status="completed")
        pool = _make_live_small_pool(db_session)
        _make_binding(db_session, v.id, pool.id, mode="live_small")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.grand_status == "paper_passed"
        assert result.next_action.code == "bind_live_small"
        assert result.next_action.target_panel == "risk"

    def test_ready_for_live_suggests_approve_live(self, db_session, svc, healthy_system_gates):
        """All gates pass + live_small run → next_action.code = approve_live."""
        s = _make_strategy(db_session)
        v = _make_version(db_session, s.id, status="live_small")
        now = datetime.now(timezone.utc)
        _make_dryrun(db_session, v.id, started_at=now - timedelta(hours=100), stopped_at=now)
        _make_backtest(db_session, s.id, status="completed")
        pool = _make_live_small_pool(db_session)
        _make_binding(db_session, v.id, pool.id, mode="live_small")
        _make_live_small_run(db_session, v.id, status="running")
        result = _call(svc, s.id, db_session, healthy_system_gates)
        assert result.grand_status == "ready_for_live"
        assert result.next_action.code == "approve_live"
        assert result.next_action.target_panel == "readiness"


# ══════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════


def _gate_by_key(gates: list[ReadinessGate], key: str) -> ReadinessGate:
    for g in gates:
        if g.key == key:
            return g
    raise AssertionError(f"Gate '{key}' not found in {[g.key for g in gates]}")
