"""Tests for RunHistoryStatsRepository — real DB queries."""
import uuid
from datetime import datetime, timezone, timedelta

from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun
from app.domain.risk import CapitalPool, RiskPolicy, RiskPolicyVersion, StrategyRiskPolicyBinding
from app.domain.strategy import StrategyV2, StrategyVersion
from app.models.strategy import BacktestRun
from app.models.dryrun import DryRunRun
from app.repositories.run_history_repository import RunHistoryStatsRepository


def _make_version(session: Session, status: str = "paper_passed") -> StrategyVersion:
    s = StrategyV2(name="Test", strategy_type="rule_dsl", source_type="manual")
    session.add(s)
    session.flush()
    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status=status,
        dsl_version="2.5", rule_dsl={}, dsl_hash="h", created_by="test",
    )
    session.add(v)
    session.flush()
    return v


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


class TestBuildStats:
    def test_nonexistent_version_returns_defaults(self, session: Session):
        repo = RunHistoryStatsRepository(session)
        stats = repo.build_stats(uuid.uuid4())
        assert stats.strategy_version_status == "draft"
        assert stats.backtest_count == 0

    def test_version_status_populated(self, session: Session):
        v = _make_version(session, status="paper_passed")
        session.commit()
        repo = RunHistoryStatsRepository(session)
        stats = repo.build_stats(v.id)
        assert stats.strategy_version_status == "paper_passed"

    def test_backtest_count(self, session: Session):
        v = _make_version(session)
        session.flush()
        for i in range(3):
            session.add(BacktestRun(
                strategy_id=0, strategy_version_id=str(v.id),
                status="completed", dsl_hash="h",
                start_date="2026-01-01", end_date="2026-01-31",
                initial_capital=10000.0,
            ))
        session.commit()
        repo = RunHistoryStatsRepository(session)
        stats = repo.build_stats(v.id)
        assert stats.backtest_count == 3

    def test_dryrun_count_and_hours(self, session: Session):
        v = _make_version(session)
        session.flush()
        now = _now()
        session.add(DryRunRun(
            strategy_id=0, strategy_version_id=str(v.id),
            status="stopped",
            started_at=now - timedelta(hours=100),
            stopped_at=now - timedelta(hours=20),
        ))
        session.add(DryRunRun(
            strategy_id=0, strategy_version_id=str(v.id),
            status="stopped",
            started_at=now - timedelta(hours=10),
            stopped_at=now - timedelta(hours=5),
        ))
        session.commit()
        repo = RunHistoryStatsRepository(session)
        stats = repo.build_stats(v.id)
        assert stats.dryrun_count == 2
        assert stats.longest_dryrun_hours >= 79.0

    def test_dryrun_failure_detected(self, session: Session):
        v = _make_version(session)
        session.flush()
        session.add(DryRunRun(
            strategy_id=0, strategy_version_id=str(v.id),
            status="failed",
        ))
        session.commit()
        repo = RunHistoryStatsRepository(session)
        stats = repo.build_stats(v.id)
        assert stats.dryrun_had_failure is True

    def test_risk_binding_detected(self, session: Session):
        v = _make_version(session)
        session.flush()
        policy = RiskPolicy(name="test", policy_type="live_small", status="active")
        session.add(policy)
        session.flush()
        pv = RiskPolicyVersion(
            risk_policy_id=policy.id, version_no=1,
            policy_json={}, policy_hash="h", status="active", created_by="test",
        )
        session.add(pv)
        session.flush()
        pool = CapitalPool(
            name="ls_pool", pool_type="live_small", currency="USDT",
            total_budget=500, max_position_pct_per_trade=0.03,
            max_total_exposure_pct=0.3, max_daily_loss_pct=0.03,
            max_drawdown_pct=0.08, requires_human_confirm=True,
        )
        session.add(pool)
        session.flush()
        binding = StrategyRiskPolicyBinding(
            strategy_version_id=v.id,
            risk_policy_version_id=pv.id,
            capital_pool_id=pool.id,
            mode="live_small",
        )
        session.add(binding)
        session.commit()
        repo = RunHistoryStatsRepository(session)
        stats = repo.build_stats(v.id)
        assert stats.has_risk_policy_binding is True
        assert stats.capital_pool_requires_human_confirm is True

    def test_active_live_small_run_detected(self, session: Session):
        v = _make_version(session)
        session.flush()
        session.add(StrategyRun(
            strategy_version_id=v.id, mode="live_small", status="running",
        ))
        session.commit()
        repo = RunHistoryStatsRepository(session)
        stats = repo.build_stats(v.id)
        assert stats.active_live_small_run_exists is True

    def test_stopped_run_not_active(self, session: Session):
        v = _make_version(session)
        session.flush()
        session.add(StrategyRun(
            strategy_version_id=v.id, mode="live_small", status="stopped",
        ))
        session.commit()
        repo = RunHistoryStatsRepository(session)
        stats = repo.build_stats(v.id)
        assert stats.active_live_small_run_exists is False
