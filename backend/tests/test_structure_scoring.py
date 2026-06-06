import pytest
from app.services.structure.models import (
    LiquiditySweep, FairValueGap, OrderBlock, LiquidityPool,
    StructureDirection, StructureStatus, SweepState, MarketRegime, PoolStatus,
)
from app.services.structure.entry_score import calculate_entry_score, BLOCKED_REGIMES
from app.services.structure.stop_calculator import calculate_structure_stop, StopResult
from app.services.structure.execution_safety import check_execution_safety


def _make_confirmed_sweep(side="sell_side"):
    pool = LiquidityPool(pool_id="p1", pool_type="equal_low", side=side,
                          price_level=61200, status=PoolStatus.SWEPT)
    return LiquiditySweep(
        sweep_id="sw1", pool=pool, state=SweepState.CONFIRMED_SWEEP,
        sweep_type=f"{side}_liquidity_sweep", swept_level=61200,
        sweep_low=61000, reclaim_price=61400, confidence=0.78,
    )


def test_entry_score_full_bullish():
    sweep = _make_confirmed_sweep("sell_side")
    fvg = FairValueGap(fvg_id="f1", direction=StructureDirection.BULLISH,
                       price_top=62000, price_bottom=61550)
    score, reasons = calculate_entry_score(
        direction=StructureDirection.BULLISH,
        sweeps=[sweep], fvgs=[fvg], order_blocks=[], structure_breaks=[],
        regime=MarketRegime.RANGE,
        higher_tf_direction=StructureDirection.BULLISH,
        volume_confirmed=True, ai_risk_score=0.3,
    )
    assert score >= 70
    assert "sell_side_sweep_confirmed" in reasons
    assert "reclaim_confirmed" in reasons
    assert "regime_allowed" in reasons

def test_entry_score_blocked_regime():
    score, reasons = calculate_entry_score(
        direction=StructureDirection.BULLISH,
        sweeps=[], fvgs=[], order_blocks=[], structure_breaks=[],
        regime=MarketRegime.PANIC,
    )
    assert score == 0
    assert "regime_blocked" in reasons

def test_entry_score_no_signals():
    score, reasons = calculate_entry_score(
        direction=StructureDirection.BULLISH,
        sweeps=[], fvgs=[], order_blocks=[], structure_breaks=[],
        regime=MarketRegime.RANGE,
    )
    assert score < 70
    assert "regime_allowed" in reasons

def test_structure_stop_bullish_with_sweep():
    sweep = _make_confirmed_sweep("sell_side")
    result = calculate_structure_stop(
        direction=StructureDirection.BULLISH,
        entry_price=61800,
        sweeps=[sweep], fvgs=[], order_blocks=[],
        atr=500, atr_buffer_coef=0.3,
    )
    assert result.stop_price < 61800
    assert result.stop_price < 61000  # below sweep low minus buffer
    assert result.stop_type == "structure_invalidated"
    assert result.distance_pct > 0

def test_structure_stop_fallback():
    result = calculate_structure_stop(
        direction=StructureDirection.BULLISH,
        entry_price=61800,
        sweeps=[], fvgs=[], order_blocks=[],
        atr=500,
    )
    assert result.stop_type == "fallback_fixed_pct"

def test_structure_stop_clamped():
    sweep = _make_confirmed_sweep("sell_side")
    sweep.sweep_low = 55000  # very far away
    result = calculate_structure_stop(
        direction=StructureDirection.BULLISH,
        entry_price=61800,
        sweeps=[sweep], fvgs=[], order_blocks=[],
        atr=500, max_stop_distance_pct=0.03,
        fallback_stop_pct=0.15,  # push fallback far so sweep candidate is tightest
    )
    assert result.stop_type == "clamped_max_distance"
    assert result.distance_pct == pytest.approx(0.03)

def test_execution_safety_normal():
    result = check_execution_safety(
        bid=61799, ask=61801, mid_price=61800,
        depth_score=0.8,
    )
    assert result.safe is True
    assert result.liquidity_state == "normal"
    assert result.action == "allow"

def test_execution_safety_wide_spread():
    result = check_execution_safety(
        bid=61600, ask=61900, mid_price=61750,
        depth_score=0.8,
        max_allowed_spread_pct=0.003,
    )
    assert result.safe is False
    assert result.liquidity_state == "wide_spread"
    assert result.action == "reject_trade"

def test_execution_safety_thin_depth():
    result = check_execution_safety(
        bid=61799, ask=61801, mid_price=61800,
        depth_score=0.2,
        min_depth_score=0.4,
    )
    assert result.safe is False
    assert result.liquidity_state == "thin_depth"
    assert result.action == "manual_confirm_required"
