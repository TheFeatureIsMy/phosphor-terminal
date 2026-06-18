"""live_small safety tests — schemas, preconditions, circuit breaker,
config generator, risk engine, API integration, security boundaries.
"""
from __future__ import annotations

import inspect
import uuid
from datetime import datetime, timezone
from typing import Literal

import pytest
from pydantic import ValidationError

from app.schemas.live_small import (
    CapitalPoolParams,
    CircuitBreakerResult,
    FreqtradeConfigPreview,
    LiveSmallApprovalResponse,
    LiveSmallConfirmPayload,
    PreconditionReport,
    RunHistoryStats,
)
from app.services.live_small.precondition_checker import check_preconditions
from app.services.live_small.circuit_breaker import TradeResult, check_circuit_breaker
from app.services.live_small.config_generator import (
    generate_config_preview,
    validate_config_safety,
)
from app.services.risk_engine import RiskEngine


# ══════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════

def _passing_stats() -> RunHistoryStats:
    return RunHistoryStats(
        strategy_version_status="paper_passed",
        backtest_count=2,
        dryrun_count=1,
        longest_dryrun_hours=100.0,
        dryrun_had_failure=False,
        has_risk_policy_binding=True,
        capital_pool_requires_human_confirm=True,
        active_live_small_run_exists=False,
    )


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


def _pool_params(**overrides) -> CapitalPoolParams:
    defaults = {
        "total_budget": 500.0,
        "max_position_pct_per_trade": 0.03,
        "max_total_exposure_pct": 0.30,
        "max_daily_loss_pct": 0.03,
        "max_drawdown_pct": 0.08,
    }
    defaults.update(overrides)
    return CapitalPoolParams(**defaults)


def _pool_dict(**overrides) -> dict:
    defaults = {
        "total_budget": 500.0,
        "max_position_pct_per_trade": 0.03,
        "max_total_exposure_pct": 0.30,
        "max_daily_loss_pct": 0.03,
        "allow_leverage": False,
        "allow_auto_trade": False,
        "requires_human_confirm": True,
    }
    defaults.update(overrides)
    return defaults


# ══════════════════════════════════════════════════════════════════════
# 1. Schema Safety
# ══════════════════════════════════════════════════════════════════════

class TestSchemas:
    def test_capital_pool_leverage_always_false(self):
        p = _pool_params()
        assert p.allow_leverage is False

    def test_capital_pool_leverage_rejects_true(self):
        with pytest.raises(ValidationError):
            CapitalPoolParams(total_budget=500, allow_leverage=True)

    def test_capital_pool_auto_trade_rejects_true(self):
        with pytest.raises(ValidationError):
            CapitalPoolParams(total_budget=500, allow_auto_trade=True)

    def test_capital_pool_human_confirm_rejects_false(self):
        with pytest.raises(ValidationError):
            CapitalPoolParams(total_budget=500, requires_human_confirm=False)

    def test_config_preview_dry_run_always_false(self):
        c = FreqtradeConfigPreview(stake_amount=15, max_open_trades=3, stoploss=-0.05)
        assert c.dry_run is False

    def test_config_preview_trading_mode_spot(self):
        c = FreqtradeConfigPreview(stake_amount=15, max_open_trades=3, stoploss=-0.05)
        assert c.trading_mode == "spot"

    def test_config_preview_listen_ip_localhost(self):
        c = FreqtradeConfigPreview(stake_amount=15, max_open_trades=3, stoploss=-0.05)
        assert c.api_server_listen_ip == "127.0.0.1"

    def test_confirm_payload_human_confirmed_must_be_true(self):
        with pytest.raises(ValidationError):
            LiveSmallConfirmPayload(
                strategy_version_id=uuid.uuid4(),
                capital_pool_id=uuid.uuid4(),
                risk_policy_version_id=uuid.uuid4(),
                human_confirmed=False,
                confirmed_by="user1",
                confirmed_at=datetime.now(timezone.utc),
            )

    def test_confirm_payload_confirmed_by_not_empty(self):
        with pytest.raises(ValidationError):
            LiveSmallConfirmPayload(
                strategy_version_id=uuid.uuid4(),
                capital_pool_id=uuid.uuid4(),
                risk_policy_version_id=uuid.uuid4(),
                confirmed_by="",
                confirmed_at=datetime.now(timezone.utc),
            )

    def test_approval_response_always_requires_confirm(self):
        r = LiveSmallApprovalResponse(preconditions=PreconditionReport())
        assert r.requires_human_confirm is True


# ══════════════════════════════════════════════════════════════════════
# 2. Precondition Checker
# ══════════════════════════════════════════════════════════════════════

class TestPreconditionChecker:
    def test_all_passing(self):
        report = check_preconditions(_passing_stats())
        assert report.all_passed is True
        assert len(report.items) == 7
        assert all(i.passed for i in report.items)

    def test_wrong_status_fails(self):
        stats = _passing_stats()
        stats.strategy_version_status = "draft"
        report = check_preconditions(stats)
        assert report.all_passed is False
        failed = [i for i in report.items if not i.passed]
        assert any("status" in i.name for i in failed)

    def test_no_backtest_fails(self):
        stats = _passing_stats()
        stats.backtest_count = 0
        report = check_preconditions(stats)
        assert report.all_passed is False

    def test_short_dryrun_fails(self):
        stats = _passing_stats()
        stats.longest_dryrun_hours = 24.0
        report = check_preconditions(stats)
        assert report.all_passed is False
        failed = [i for i in report.items if not i.passed]
        assert any("dryrun_duration" in i.name for i in failed)

    def test_dryrun_failure_fails(self):
        stats = _passing_stats()
        stats.dryrun_had_failure = True
        report = check_preconditions(stats)
        assert report.all_passed is False

    def test_no_risk_binding_fails(self):
        stats = _passing_stats()
        stats.has_risk_policy_binding = False
        report = check_preconditions(stats)
        assert report.all_passed is False

    def test_active_run_fails(self):
        stats = _passing_stats()
        stats.active_live_small_run_exists = True
        report = check_preconditions(stats)
        assert report.all_passed is False


# ══════════════════════════════════════════════════════════════════════
# 3. Circuit Breaker
# ══════════════════════════════════════════════════════════════════════

class TestCircuitBreaker:
    def test_no_trades_safe(self):
        r = check_circuit_breaker([], total_budget=500)
        assert r["should_stop"] is False
        assert r["consecutive_losses"] == 0

    def test_daily_loss_triggers_stop(self):
        trades = [
            TradeResult(profit_abs=-10, profit_pct=-0.02, is_win=False),
            TradeResult(profit_abs=-8, profit_pct=-0.016, is_win=False),
        ]
        r = check_circuit_breaker(trades, total_budget=500, max_daily_loss_pct=0.03)
        assert r["should_stop"] is True
        assert r["daily_loss_pct"] >= 0.03

    def test_consecutive_loss_cooldown(self):
        trades = [
            TradeResult(profit_abs=5, profit_pct=0.01, is_win=True),
            TradeResult(profit_abs=-2, profit_pct=-0.004, is_win=False),
            TradeResult(profit_abs=-2, profit_pct=-0.004, is_win=False),
            TradeResult(profit_abs=-2, profit_pct=-0.004, is_win=False),
        ]
        r = check_circuit_breaker(trades, total_budget=500, max_consecutive_losses=3)
        assert r["should_cooldown"] is True
        assert r["consecutive_losses"] == 3

    def test_hard_stop_on_5_consecutive(self):
        trades = [TradeResult(profit_abs=-1, profit_pct=-0.002, is_win=False) for _ in range(5)]
        r = check_circuit_breaker(trades, total_budget=500, hard_stop_consecutive=5)
        assert r["should_stop"] is True
        assert r["consecutive_losses"] == 5

    def test_win_resets_consecutive(self):
        trades = [
            TradeResult(profit_abs=-1, profit_pct=-0.002, is_win=False),
            TradeResult(profit_abs=-1, profit_pct=-0.002, is_win=False),
            TradeResult(profit_abs=5, profit_pct=0.01, is_win=True),
        ]
        r = check_circuit_breaker(trades, total_budget=500)
        assert r["consecutive_losses"] == 0


# ══════════════════════════════════════════════════════════════════════
# 4. Config Generator
# ══════════════════════════════════════════════════════════════════════

class TestConfigGenerator:
    def test_generates_valid_config(self):
        dsl = _sample_dsl()
        pool = _pool_params()
        config = generate_config_preview(dsl, pool)
        assert config.dry_run is False
        assert config.trading_mode == "spot"
        assert config.stoploss < 0
        assert config.stake_amount > 0
        assert config.max_open_trades >= 1
        assert len(config.protections) >= 3

    def test_stake_within_budget(self):
        dsl = _sample_dsl()
        pool = _pool_params(total_budget=100)
        config = generate_config_preview(dsl, pool)
        assert config.stake_amount * config.max_open_trades <= 100

    def test_invalid_stoploss_gets_default(self):
        dsl = _sample_dsl()
        dsl["risk"]["stoploss"] = 0.05
        pool = _pool_params()
        config = generate_config_preview(dsl, pool)
        assert config.stoploss == -0.05

    def test_validate_config_safety_clean(self):
        dsl = _sample_dsl()
        pool = _pool_params()
        config = generate_config_preview(dsl, pool)
        errors = validate_config_safety(config, pool)
        assert errors == []

    def test_pair_whitelist_from_dsl(self):
        dsl = _sample_dsl()
        pool = _pool_params()
        config = generate_config_preview(dsl, pool)
        assert config.pair_whitelist == ["BTC/USDT"]


# ══════════════════════════════════════════════════════════════════════
# 5. RiskEngine pre_live_small_check
# ══════════════════════════════════════════════════════════════════════

class TestRiskEngineLiveSmall:
    def test_valid_dsl_and_pool_approved(self):
        engine = RiskEngine()
        r = engine.pre_live_small_check(_sample_dsl(), _pool_dict())
        assert r.approved is True

    def test_missing_stoploss_rejected(self):
        engine = RiskEngine()
        dsl = _sample_dsl()
        del dsl["risk"]["stoploss"]
        r = engine.pre_live_small_check(dsl, _pool_dict())
        assert r.approved is False

    def test_positive_stoploss_rejected(self):
        engine = RiskEngine()
        dsl = _sample_dsl()
        dsl["risk"]["stoploss"] = 0.05
        r = engine.pre_live_small_check(dsl, _pool_dict())
        assert r.approved is False

    def test_leverage_rejected(self):
        engine = RiskEngine()
        r = engine.pre_live_small_check(_sample_dsl(), _pool_dict(allow_leverage=True))
        assert r.approved is False
        codes = [e["code"] for e in r.errors]
        assert "LIVE_SMALL_LEVERAGE_FORBIDDEN" in codes

    def test_auto_trade_rejected(self):
        engine = RiskEngine()
        r = engine.pre_live_small_check(_sample_dsl(), _pool_dict(allow_auto_trade=True))
        assert r.approved is False

    def test_no_human_confirm_rejected(self):
        engine = RiskEngine()
        r = engine.pre_live_small_check(_sample_dsl(), _pool_dict(requires_human_confirm=False))
        assert r.approved is False

    def test_high_daily_loss_rejected(self):
        engine = RiskEngine()
        r = engine.pre_live_small_check(_sample_dsl(), _pool_dict(max_daily_loss_pct=0.15))
        assert r.approved is False
        codes = [e["code"] for e in r.errors]
        assert "LIVE_SMALL_DAILY_LOSS_TOO_HIGH" in codes


# ══════════════════════════════════════════════════════════════════════
# 6. API Integration
# ══════════════════════════════════════════════════════════════════════

class TestLiveSmallAPI:
    def test_precondition_check_endpoint(self, client):
        resp = client.post("/api/live-small/precondition-check", json={
            "strategy_version_id": str(uuid.uuid4()),
            "capital_pool_id": str(uuid.uuid4()),
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "all_passed" in data
        assert "items" in data

    def test_evaluate_endpoint_missing_version(self, client):
        resp = client.post("/api/live-small/evaluate", json={
            "strategy_version_id": str(uuid.uuid4()),
            "capital_pool_id": str(uuid.uuid4()),
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["can_proceed"] is False
        assert data["requires_human_confirm"] is True

    def test_circuit_breaker_endpoint_not_found(self, client):
        resp = client.post("/api/live-small/circuit-breaker-check", json={
            "strategy_run_id": str(uuid.uuid4()),
        })
        assert resp.status_code == 404

    def test_circuit_breaker_with_run(self, client, session):
        from app.domain.strategy import StrategyV2, StrategyVersion
        from app.domain.execution import StrategyRun
        s = StrategyV2(name="CB", strategy_type="rule_dsl", source_type="manual")
        session.add(s)
        session.flush()
        v = StrategyVersion(
            strategy_id=s.id, version_no=1, status="live_small",
            dsl_version="2.5", rule_dsl={}, dsl_hash="h", created_by="test",
        )
        session.add(v)
        session.flush()
        run = StrategyRun(strategy_version_id=v.id, mode="live_small", status="running")
        session.add(run)
        session.commit()
        resp = client.post("/api/live-small/circuit-breaker-check", json={
            "strategy_run_id": str(run.id),
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["should_stop"] is False
        assert data["total_trades_today"] == 0


# ══════════════════════════════════════════════════════════════════════
# 7. Security Boundaries
# ══════════════════════════════════════════════════════════════════════

class TestSecurityBoundary:
    def test_service_literal_safety(self):
        from typing import get_type_hints
        from app.services.live_small.live_small_service import LiveSmallService
        hints = get_type_hints(LiveSmallService, include_extras=True)
        assert hints.get("can_execute") == Literal[False]
        assert hints.get("auto_start") == Literal[False]
        assert hints.get("requires_human_confirm") == Literal[True]

    def test_service_no_forbidden_imports(self):
        from app.services.live_small import live_small_service
        src = inspect.getsource(live_small_service)
        for forbidden in ["FreqtradeAdapter", "TradeIntent", "import docker"]:
            assert forbidden not in src, f"live_small_service must not reference {forbidden}"

    def test_router_no_forbidden_imports(self):
        from app.routers import live_small
        src = inspect.getsource(live_small)
        for forbidden in ["FreqtradeAdapter", "TradeIntent", "import docker"]:
            assert forbidden not in src, f"live_small router must not reference {forbidden}"

    def test_config_generator_no_file_write(self):
        from app.services.live_small import config_generator
        src = inspect.getsource(config_generator)
        for forbidden in ["open(", "write(", "Path(", "os.path", "shutil"]:
            assert forbidden not in src, f"config_generator must not use {forbidden}"

    def test_circuit_breaker_no_command_bus(self):
        from app.services.live_small import circuit_breaker
        src = inspect.getsource(circuit_breaker)
        assert "CommandBus" not in src
        assert "EmergencyStop" not in src


# ══════════════════════════════════════════════════════════════════════
# Live Readiness Service — 11 checks + 5-level grand_status
# ══════════════════════════════════════════════════════════════════════

class TestLiveReadinessService:
    """Tests for the unified LiveReadinessService used by /api/overview/live-readiness."""

    @pytest.fixture
    def svc(self):
        from app.services.live_readiness_service import LiveReadinessService
        s = LiveReadinessService(redis_store=None, freqtrade_client=None)
        # Stub infra checks to bypass DB/Redis/Freqtrade dependency
        s._check_redis = _async_result("healthy", "1ms")
        s._check_freqtrade = _async_result("healthy", "running")
        s._check_database = lambda: _sync_result("healthy", "ok")
        s._check_risk_state = _async_result("healthy", "normal")
        return s

    def test_returns_11_named_checks(self, svc):
        import asyncio
        r = asyncio.run(svc.evaluate(
            selected_mode="live_small",
            selected_strategy_id="s1",
            selected_capital_pool_id="cp1",
            selected_exchange="binance",
        ))
        keys = {c.key for c in r.checks}
        expected = {"mode", "strategy", "capital", "risk_config", "exchange",
                    "data_source", "validation", "backtest", "dryrun",
                    "notification", "emergency_stop"}
        assert expected.issubset(keys), f"missing checks: {expected - keys}"

    def test_grand_status_ready_for_live(self, svc):
        import asyncio
        r = asyncio.run(svc.evaluate(selected_mode='live_small', selected_strategy_id='s1', selected_capital_pool_id='cp1', selected_exchange='binance'))
        assert r.grand_status == "ready_for_live"
        assert r.can_start_live_small is True
        assert r.can_start_paper is True

    def test_grand_status_paper_passed(self, svc):
        import asyncio
        r = asyncio.run(svc.evaluate(selected_mode='paper', selected_strategy_id='s1', selected_capital_pool_id='cp1', selected_exchange='binance'))
        assert r.grand_status == "paper_passed"
        assert r.can_start_paper is True
        assert r.can_start_live_small is False

    def test_grand_status_full_live(self, svc):
        import asyncio
        r = asyncio.run(svc.evaluate(selected_mode='live_full', selected_strategy_id='s1', selected_capital_pool_id='cp1', selected_exchange='binance'))
        assert r.grand_status == "ready_for_live"
        assert r.can_start_live_small is True
        assert r.can_start_full_live is True

    def test_grand_status_needs_config_when_strategy_missing(self, svc):
        import asyncio
        r = asyncio.run(svc.evaluate(selected_mode='live_small', selected_strategy_id='', selected_capital_pool_id='cp1', selected_exchange='binance'))
        assert r.grand_status == "needs_config"
        assert r.can_start_live_small is False

    def test_grand_status_needs_config_when_all_empty(self, svc):
        import asyncio
        r = asyncio.run(svc.evaluate(selected_mode='', selected_strategy_id='', selected_capital_pool_id='', selected_exchange=''))
        assert r.grand_status == "needs_config"

    def test_grand_status_not_live_when_db_down(self, svc):
        import asyncio
        svc._check_database = lambda: _sync_result("failed", "error")
        r = asyncio.run(svc.evaluate(selected_mode='live_small', selected_strategy_id='s1', selected_capital_pool_id='cp1', selected_exchange='binance'))
        assert r.grand_status == "not_live"
        assert r.can_start_live_small is False
        assert r.can_start_paper is False

    def test_grand_status_needs_validation_when_dryrun_fails(self, svc):
        import asyncio
        svc._check_dryrun = staticmethod(
            lambda sid: _check_dryrun(sid, healthy=False)
        )
        r = asyncio.run(svc.evaluate(selected_mode='live_small', selected_strategy_id='s1', selected_capital_pool_id='cp1', selected_exchange='binance'))
        assert r.grand_status == "needs_validation"

    def test_selected_context_preserved(self, svc):
        import asyncio
        r = asyncio.run(svc.evaluate(selected_mode='live_small', selected_strategy_id='v2:btc-scalp', selected_capital_pool_id='cp-007', selected_exchange='binance'))
        assert r.selected_mode == "live_small"
        assert r.selected_strategy_id == "v2:btc-scalp"
        assert r.selected_capital_pool_id == "cp-007"
        assert r.selected_exchange == "binance"

    def test_legacy_state_mapping(self, svc):
        import asyncio
        # ready_for_live → LIVE_READY
        r = asyncio.run(svc.evaluate(selected_mode='live_small', selected_strategy_id='s1', selected_capital_pool_id='cp1', selected_exchange='binance'))
        assert r.state == "LIVE_READY"
        # paper_passed → LIVE_SMALL_READY
        r = asyncio.run(svc.evaluate(selected_mode='paper', selected_strategy_id='s1', selected_capital_pool_id='cp1', selected_exchange='binance'))
        assert r.state == "LIVE_SMALL_READY"
        # needs_config → NOT_READY
        r = asyncio.run(svc.evaluate(selected_mode='', selected_strategy_id='', selected_capital_pool_id='', selected_exchange=''))
        assert r.state == "NOT_READY"

    def test_serialize_round_trip(self, svc):
        import asyncio
        from app.services.live_readiness_service import LiveReadinessService
        r = asyncio.run(svc.evaluate(selected_mode='live_small', selected_strategy_id='s1', selected_capital_pool_id='cp1', selected_exchange='binance'))
        d = LiveReadinessService._serialize(r)
        assert d["grand_status"] == "ready_for_live"
        assert d["selected_mode"] == "live_small"
        assert isinstance(d["checks"], list)
        for c in d["checks"]:
            assert {"key", "label", "status", "value", "threshold", "detail", "group"} <= c.keys()


def _check_dryrun(strategy_id: str, healthy: bool = True):
    from app.services.live_readiness_service import CheckResult
    if healthy:
        return CheckResult(key="dryrun", label="模拟/dry-run", status="healthy",
                           value="100h", threshold="≥72h", group="execution")
    return CheckResult(key="dryrun", label="模拟/dry-run", status="failed",
                       value="0h", threshold="≥72h", group="execution")


def _sync_result(status, value):
    from app.services.live_readiness_service import CheckResult
    return CheckResult(key="tbd", label="tbd", status=status, value=value)


def _async_result(status, value):
    from app.services.live_readiness_service import CheckResult
    async def _inner(*args, **kwargs):
        return CheckResult(key="tbd", label="tbd", status=status, value=value)
    return _inner
