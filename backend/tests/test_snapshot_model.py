import pytest
from datetime import datetime, timezone
from app.domain.snapshot import (
    RuntimeDecisionSnapshot, CandidateSignal, IndicatorContext,
    StructureContext, AIContext, LiquidityExecutionContext,
    RiskContext, ExecutionPlan,
)

def test_snapshot_construction():
    snap = RuntimeDecisionSnapshot(
        snapshot_id="snap_001",
        strategy_id="strat_1",
        exchange="binance",
        symbol="BTC/USDT",
        timeframe="5m",
        candidate_signal=CandidateSignal(
            direction="long", intent="open_position",
            confidence=0.72, reason_codes=["rsi_oversold"]
        ),
        indicator_context=IndicatorContext(values={"rsi_14": 28.4, "atr_14": 510.2}),
        risk_context=RiskContext(account_risk_state="allowed", risk_per_trade=0.01,
                                daily_loss_remaining=0.024, weekly_loss_remaining=0.065),
        execution_plan=ExecutionPlan(decision="allow_trade", entry_price=61780,
                                     stop_price=60880, position_size=0.111),
        reason_codes=["structure_confirmed", "account_risk_allowed"],
    )
    assert snap.snapshot_id == "snap_001"
    assert snap.candidate_signal.direction == "long"
    assert snap.execution_plan.decision == "allow_trade"
    assert snap.valid_until > snap.generated_at

def test_snapshot_json_round_trip():
    snap = RuntimeDecisionSnapshot(
        snapshot_id="snap_002",
        strategy_id="strat_1",
        exchange="binance",
        symbol="BTC/USDT",
        timeframe="5m",
        candidate_signal=CandidateSignal(
            direction="long", intent="open_position",
            confidence=0.5, reason_codes=["test"]
        ),
        execution_plan=ExecutionPlan(decision="reject_trade",
                                     reject_reason="daily_loss_limit"),
        reason_codes=["daily_loss_limit_reached"],
    )
    data = snap.model_dump(mode="json")
    restored = RuntimeDecisionSnapshot.model_validate(data)
    assert restored.snapshot_id == snap.snapshot_id
    assert restored.execution_plan.decision == "reject_trade"

def test_execution_plan_reject():
    plan = ExecutionPlan(decision="reject_trade", reject_reason="kill_switch_active")
    assert plan.entry_price is None
    assert plan.stop_price is None

def test_ai_context_defaults():
    ctx = AIContext()
    assert ctx.cache_state == "missing"
    assert ctx.ai_risk_score == 0.0

def test_structure_context_defaults():
    ctx = StructureContext()
    assert ctx.market_regime == "unknown"
    assert ctx.structure_score == 0
