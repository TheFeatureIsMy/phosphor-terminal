"""Tests for StrategyWorkspaceAggregator + summarize_dsl helper.

TDD: helper tests + 7 aggregator tests.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

import pytest

from app.domain.execution import StrategyRun
from app.domain.strategy import StrategyV2, StrategyVersion
from app.domain.risk import RiskPolicy, RiskPolicyVersion, CapitalPool, StrategyRiskPolicyBinding
from app.models.strategy import BacktestRun
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash
from app.services.live_readiness_service import LiveReadinessService
from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.strategy_activity_service import StrategyActivityService
from app.services.strategy_binding_service import StrategyBindingService


# ── Fixtures ──────────────────────────────────────────────────────────

@pytest.fixture
def db_session(session):
    return session


@pytest.fixture
def store():
    return RuntimeRedisStore(redis_url=None)


@pytest.fixture
def base_dsl():
    return {
        "schema_version": "2.5",
        "symbols": ["BTC/USDT", "ETH/USDT"],
        "timeframe": "1h",
        "entry": {
            "logic": "AND",
            "rules": [
                {"indicator": "RSI", "operator": "<", "value": 30},
                {"indicator": "VOL", "operator": ">", "value": 1.5},
            ],
        },
        "exit": {
            "rules": [
                {"indicator": "RSI", "operator": ">", "value": 70},
                {"indicator": "EMA", "operator": "<", "value": "close"},
            ],
        },
        "filters": [
            {"indicator": "ADX", "operator": ">", "value": 25},
        ],
    }


@pytest.fixture
def strategy(db_session):
    s = StrategyV2(name="test-strat", strategy_type="rule_dsl", source_type="manual", status="draft")
    repo = StrategyRepository(db_session)
    repo.create_strategy(s)
    db_session.flush()
    return s


@pytest.fixture
def version(db_session, strategy, base_dsl):
    v = StrategyVersion(
        strategy_id=strategy.id, version_no=1, status="draft",
        dsl_version="2.5", rule_dsl=base_dsl,
        dsl_hash=compute_dsl_hash(base_dsl), created_by="u",
    )
    db_session.add(v)
    db_session.flush()
    return v


@pytest.fixture
def policy_and_pool(db_session):
    rp = RiskPolicy(name="conservative", policy_type="conservative", status="active")
    db_session.add(rp)
    db_session.flush()
    rpv = RiskPolicyVersion(
        risk_policy_id=rp.id, version_no=1,
        policy_json={"max_position_pct": 0.02},
        policy_hash="abc", status="active", created_by="u",
    )
    db_session.add(rpv)
    db_session.flush()
    pool = CapitalPool(
        name="ls", pool_type="live_small", currency="USDT",
        total_budget=5000, max_position_pct_per_trade=0.02,
        max_total_exposure_pct=0.5, max_daily_loss_pct=0.05, max_drawdown_pct=0.15,
    )
    db_session.add(pool)
    db_session.commit()
    return dict(rpv=rpv, pool=pool)


# ── Import the service under test ─────────────────────────────────────
from app.services.strategy_workspace_aggregator import (  # noqa: E402
    StrategyWorkspaceAggregator, summarize_dsl, extract_data_dependencies,
)
from app.schemas.strategy_workspace import (  # noqa: E402
    SignalLogicSummary, DataDependencies,
)


# ═══════════════════════════════════════════════════════════════════════
# Helper tests
# ═══════════════════════════════════════════════════════════════════════

class TestSummarizeDSL:
    def test_entry_text_from_rules_and_logic(self):
        dsl = {
            "entry": {
                "logic": "AND",
                "rules": [
                    {"indicator": "RSI", "operator": "<", "value": 30},
                    {"indicator": "VOL", "operator": ">", "value": 1.5},
                ],
            },
            "exit": {"rules": []},
            "filters": [],
        }
        result = summarize_dsl(dsl)
        assert isinstance(result, SignalLogicSummary)
        assert "RSI<30" in result.entry_text
        assert "VOL>1.5" in result.entry_text
        assert " AND " in result.entry_text

    def test_exit_text_from_exit_rules(self):
        dsl = {
            "entry": {"rules": [], "logic": "AND"},
            "exit": {
                "rules": [
                    {"indicator": "RSI", "operator": ">", "value": 70},
                    {"indicator": "EMA", "operator": "<", "value": "close"},
                ],
            },
            "filters": [],
        }
        result = summarize_dsl(dsl)
        assert "RSI>70" in result.exit_text
        assert "EMA<close" in result.exit_text
        assert " OR " in result.exit_text

    def test_handles_empty_rules(self):
        dsl = {
            "entry": {"rules": [], "logic": "AND"},
            "exit": {"rules": []},
            "filters": [],
        }
        result = summarize_dsl(dsl)
        assert result.entry_text == "(empty)"
        assert result.exit_text == "(empty)"
        assert result.filter_count == 0

    def test_filter_count(self):
        dsl = {
            "entry": {"rules": [], "logic": "AND"},
            "exit": {"rules": []},
            "filters": [{"indicator": "ADX"}, {"indicator": "VOL"}],
        }
        result = summarize_dsl(dsl)
        assert result.filter_count == 2


class TestDataDependencies:
    def test_extracts_symbols_timeframes_indicators(self, base_dsl):
        from app.services.strategy_workspace_aggregator import extract_data_dependencies
        dd = extract_data_dependencies(base_dsl)
        assert isinstance(dd, DataDependencies)
        assert "BTC/USDT" in dd.symbols
        assert "ETH/USDT" in dd.symbols
        assert "1h" in dd.timeframes
        assert "RSI" in dd.indicators
        assert "VOL" in dd.indicators
        assert "ADX" in dd.indicators

    def test_handles_missing_fields(self):
        dd = extract_data_dependencies({})
        assert dd.symbols == []
        assert dd.timeframes == []
        assert dd.indicators == []
        assert dd.signal_sources == []


# ═══════════════════════════════════════════════════════════════════════
# Aggregator tests
# ═══════════════════════════════════════════════════════════════════════

class TestStrategyWorkspaceAggregator:
    """Aggregator integration tests with real DB + in-memory Redis fallback."""

    @pytest.mark.asyncio
    async def test_full_snapshot_happy(
        self, db_session, store, strategy, version, base_dsl, policy_and_pool,
    ):
        """Happy path: full snapshot with all 11 fields populated."""
        # Arrange: add a binding
        svc_binding = StrategyBindingService(db_session, StrategyActivityService(db_session))
        svc_binding.create(
            strategy_id=strategy.id, strategy_version_id=version.id,
            risk_policy_version_id=policy_and_pool["rpv"].id,
            capital_pool_id=policy_and_pool["pool"].id,
            mode="live_small", actor="api",
        )
        db_session.commit()

        # Add a backtest run
        bt = BacktestRun(
            strategy_id=0,  # legacy int
            strategy_uuid=strategy.id,
            strategy_version_uuid=version.id,
            status="completed",
            start_date="2024-01-01", end_date="2024-02-01",
            initial_capital=10000, symbols=["BTC/USDT"],
            total_return=0.05, win_rate=0.6, max_drawdown=0.1, sharpe_ratio=1.5,
            completed_at=datetime.now(timezone.utc),
        )
        db_session.add(bt)
        db_session.commit()

        # Add a dry_run StrategyRun
        run = StrategyRun(
            strategy_version_id=version.id,
            capital_pool_id=policy_and_pool["pool"].id,
            mode="dry_run", status="running",
            started_at=datetime.now(timezone.utc),
        )
        db_session.add(run)
        db_session.commit()

        # Add some activity
        activity_svc = StrategyActivityService(db_session)
        activity_svc.record(strategy.id, "version_created", "v1 created",
                            actor="api", ref_kind="version", ref_id=version.id)
        db_session.commit()

        # Act
        aggregator = StrategyWorkspaceAggregator(
            db=db_session,
            redis_store=store,
            readiness_svc=LiveReadinessService(),
            binding_svc=svc_binding,
            activity_svc=activity_svc,
        )
        snapshot = await aggregator.get_snapshot(strategy.id)

        # Assert — 11 fields
        assert snapshot.strategy.id == strategy.id
        assert len(snapshot.versions) >= 1
        assert snapshot.latest_version_id == version.id
        assert len(snapshot.bindings) == 1
        assert len(snapshot.recent_backtests) == 1
        assert snapshot.recent_backtests[0].total_return == 0.05
        assert len(snapshot.recent_dryruns) == 1
        assert snapshot.recent_dryruns[0].mode == "dry_run"
        assert snapshot.readiness.total == 11
        assert len(snapshot.activity) >= 1
        assert snapshot.activity[0].kind == "version_created"
        # Nested ref
        assert snapshot.activity[0].ref is not None
        assert snapshot.activity[0].ref.kind == "version"
        assert snapshot.activity[0].ref.id == version.id
        # Signal logic summary
        assert snapshot.signal_logic_summary.entry_text != ""
        assert snapshot.signal_logic_summary.filter_count == 1
        # Data dependencies
        assert "BTC/USDT" in snapshot.data_dependencies.symbols
        assert "1h" in snapshot.data_dependencies.timeframes

    @pytest.mark.asyncio
    async def test_no_versions(self, db_session, store, strategy):
        """Strategy with no versions — snapshot returns latest_version_id=None, empty arrays,
        readiness still computed."""
        activity_svc = StrategyActivityService(db_session)
        binding_svc = StrategyBindingService(db_session, activity_svc)

        aggregator = StrategyWorkspaceAggregator(
            db=db_session, redis_store=store,
            readiness_svc=LiveReadinessService(),
            binding_svc=binding_svc,
            activity_svc=activity_svc,
        )
        snapshot = await aggregator.get_snapshot(strategy.id)

        assert snapshot.strategy.id == strategy.id
        assert snapshot.latest_version_id is None
        assert snapshot.versions == []
        assert snapshot.bindings == []
        assert snapshot.recent_backtests == []
        assert snapshot.recent_dryruns == []
        assert snapshot.activity == []
        assert snapshot.readiness.total == 11
        # Signal logic with no version should still be present (default empty)
        assert snapshot.signal_logic_summary.entry_text == ""

    @pytest.mark.asyncio
    async def test_no_bindings(self, db_session, store, strategy, version):
        """Strategy with no bindings — empty bindings array."""
        activity_svc = StrategyActivityService(db_session)
        binding_svc = StrategyBindingService(db_session, activity_svc)

        aggregator = StrategyWorkspaceAggregator(
            db=db_session, redis_store=store,
            readiness_svc=LiveReadinessService(),
            binding_svc=binding_svc,
            activity_svc=activity_svc,
        )
        snapshot = await aggregator.get_snapshot(strategy.id)

        assert snapshot.bindings == []

    @pytest.mark.asyncio
    async def test_no_runs(self, db_session, store, strategy, version, policy_and_pool):
        """Strategy with no runs — empty recent_backtests and recent_dryruns."""
        activity_svc = StrategyActivityService(db_session)
        binding_svc = StrategyBindingService(db_session, activity_svc)

        aggregator = StrategyWorkspaceAggregator(
            db=db_session, redis_store=store,
            readiness_svc=LiveReadinessService(),
            binding_svc=binding_svc,
            activity_svc=activity_svc,
        )
        snapshot = await aggregator.get_snapshot(strategy.id)

        assert snapshot.recent_backtests == []
        assert snapshot.recent_dryruns == []

    @pytest.mark.asyncio
    async def test_redis_miss_falls_through_to_db(
        self, db_session, store, strategy, version,
    ):
        """Redis miss → falls through to DB."""
        activity_svc = StrategyActivityService(db_session)
        binding_svc = StrategyBindingService(db_session, activity_svc)

        aggregator = StrategyWorkspaceAggregator(
            db=db_session, redis_store=store,
            readiness_svc=LiveReadinessService(),
            binding_svc=binding_svc,
            activity_svc=activity_svc,
        )
        snapshot = await aggregator.get_snapshot(strategy.id)

        assert snapshot.strategy.id == strategy.id
        assert snapshot.latest_version_id == version.id

    @pytest.mark.asyncio
    async def test_redis_hit_skips_db(
        self, db_session, store, strategy, version,
    ):
        """Redis hit → uses cache, verify by populating redis manually."""
        activity_svc = StrategyActivityService(db_session)
        binding_svc = StrategyBindingService(db_session, activity_svc)

        aggregator = StrategyWorkspaceAggregator(
            db=db_session, redis_store=store,
            readiness_svc=LiveReadinessService(),
            binding_svc=binding_svc,
            activity_svc=activity_svc,
        )
        # First call populates cache
        snapshot1 = await aggregator.get_snapshot(strategy.id)

        # Manually overwrite cache with known data
        cache_key = f"pulsedesk:workspace:{strategy.id}"
        await store._set(cache_key, {"strategy": {"id": str(strategy.id), "name": "CACHED", "strategy_type": "rule_dsl", "source_type": "manual", "status": "draft"}, "versions": [], "latest_version_id": None, "bindings": [], "recent_backtests": [], "recent_dryruns": [], "readiness": {"passed_count": 0, "total": 11, "grand_status": "not_live", "next_action": {"code": "none", "label": "", "target_panel": None}, "strategy_gates": [], "system_gates": []}, "activity": [], "signal_logic_summary": {"entry_text": "CACHED", "exit_text": "", "filter_count": 0}, "data_dependencies": {"symbols": [], "timeframes": [], "indicators": [], "signal_sources": []}}, ttl=30)

        snapshot2 = await aggregator.get_snapshot(strategy.id)
        assert snapshot2.strategy.name == "CACHED"
        assert snapshot2.signal_logic_summary.entry_text == "CACHED"

    @pytest.mark.asyncio
    async def test_force_fresh_bypasses_cache(
        self, db_session, store, strategy, version,
    ):
        """force_fresh=True bypasses cache."""
        activity_svc = StrategyActivityService(db_session)
        binding_svc = StrategyBindingService(db_session, activity_svc)

        aggregator = StrategyWorkspaceAggregator(
            db=db_session, redis_store=store,
            readiness_svc=LiveReadinessService(),
            binding_svc=binding_svc,
            activity_svc=activity_svc,
        )
        # Populate cache with stale data
        cache_key = f"pulsedesk:workspace:{strategy.id}"
        await store._set(cache_key, {"strategy": {"id": str(strategy.id), "name": "STALE", "strategy_type": "rule_dsl", "source_type": "manual", "status": "draft"}, "versions": [], "latest_version_id": None, "bindings": [], "recent_backtests": [], "recent_dryruns": [], "readiness": {"passed_count": 0, "total": 11, "grand_status": "not_live", "next_action": {"code": "none", "label": "", "target_panel": None}, "strategy_gates": [], "system_gates": []}, "activity": [], "signal_logic_summary": {"entry_text": "", "exit_text": "", "filter_count": 0}, "data_dependencies": {"symbols": [], "timeframes": [], "indicators": [], "signal_sources": []}}, ttl=30)

        # force_fresh=True should bypass cache
        snapshot = await aggregator.get_snapshot(strategy.id, force_fresh=True)
        assert snapshot.strategy.name == "test-strat"  # real name, not STALE

    @pytest.mark.asyncio
    async def test_cache_failure_does_not_break_request(
        self, db_session, strategy, version,
    ):
        """When Redis store is None, cache ops should be no-ops and request still works."""
        activity_svc = StrategyActivityService(db_session)
        binding_svc = StrategyBindingService(db_session, activity_svc)

        aggregator = StrategyWorkspaceAggregator(
            db=db_session, redis_store=None,
            readiness_svc=LiveReadinessService(),
            binding_svc=binding_svc,
            activity_svc=activity_svc,
        )
        snapshot = await aggregator.get_snapshot(strategy.id)

        assert snapshot.strategy.id == strategy.id
        assert snapshot.latest_version_id == version.id

    @pytest.mark.asyncio
    async def test_bindings_spans_all_versions(
        self, db_session, store, strategy, version, policy_and_pool,
    ):
        """bindings list spans all versions of the strategy (not just latest)."""
        # Create a second version
        dsl2 = {"schema_version": "2.5", "timeframe": "4h"}
        v2 = StrategyVersion(
            strategy_id=strategy.id, version_no=2, status="draft",
            dsl_version="2.5", rule_dsl=dsl2,
            dsl_hash=compute_dsl_hash(dsl2), created_by="u",
        )
        db_session.add(v2)
        db_session.flush()

        activity_svc = StrategyActivityService(db_session)
        binding_svc = StrategyBindingService(db_session, activity_svc)

        # Bind on v1
        binding_svc.create(
            strategy_id=strategy.id, strategy_version_id=version.id,
            risk_policy_version_id=policy_and_pool["rpv"].id,
            capital_pool_id=policy_and_pool["pool"].id,
            mode="live_small", actor="api",
        )
        db_session.commit()

        aggregator = StrategyWorkspaceAggregator(
            db=db_session, redis_store=store,
            readiness_svc=LiveReadinessService(),
            binding_svc=binding_svc,
            activity_svc=activity_svc,
        )
        snapshot = await aggregator.get_snapshot(strategy.id)
        assert len(snapshot.bindings) == 1
