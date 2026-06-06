import pytest
from app.services.structure.models import (
    LiquidityPool, FairValueGap, OrderBlock, SwingPoint,
    StructureStatus, PoolStatus, StructureDirection, SweepState,
    MarketRegime, StructureSnapshot,
)
from app.services.structure.timeframe import can_invalidate_structure, get_rank
from app.services.structure.lifecycle import (
    decay_strength, update_fvg_lifecycle, update_ob_lifecycle, update_pool_lifecycle,
)


def test_timeframe_rank():
    assert get_rank("1m") == 1
    assert get_rank("1h") == 6
    assert get_rank("1d") == 9

def test_can_invalidate_same_tf():
    assert can_invalidate_structure("5m", "5m") is True

def test_cannot_invalidate_higher_tf():
    assert can_invalidate_structure("5m", "1h") is False

def test_can_invalidate_lower_tf():
    assert can_invalidate_structure("1h", "5m") is True

def test_decay_strength_fresh():
    s = decay_strength(0.8, age_bars=0, touched_count=0, filled_ratio=0.0)
    assert s == 0.8

def test_decay_strength_aged():
    s = decay_strength(0.8, age_bars=100, touched_count=2, filled_ratio=0.5)
    assert s < 0.8
    assert s > 0.0

def test_decay_strength_fully_filled():
    s = decay_strength(0.8, age_bars=0, touched_count=0, filled_ratio=1.0)
    assert s == pytest.approx(0.4)

def test_fvg_bullish_touched():
    fvg = FairValueGap(
        fvg_id="fvg1", direction=StructureDirection.BULLISH,
        price_top=62000, price_bottom=61550, timeframe="5m",
    )
    fvg = update_fvg_lifecycle(fvg, current_close=61800, current_low=61700,
                                current_high=62100, candle_tf="5m")
    assert fvg.status == StructureStatus.TOUCHED
    assert fvg.touched_count == 1
    assert fvg.filled_ratio > 0

def test_fvg_bullish_invalidated_same_tf():
    fvg = FairValueGap(
        fvg_id="fvg2", direction=StructureDirection.BULLISH,
        price_top=62000, price_bottom=61550, timeframe="5m",
    )
    fvg = update_fvg_lifecycle(fvg, current_close=61000, current_low=60900,
                                current_high=61600, candle_tf="5m")
    assert fvg.status == StructureStatus.INVALIDATED

def test_fvg_bullish_not_invalidated_lower_tf():
    fvg = FairValueGap(
        fvg_id="fvg3", direction=StructureDirection.BULLISH,
        price_top=62000, price_bottom=61550, timeframe="1h",
    )
    fvg = update_fvg_lifecycle(fvg, current_close=61000, current_low=60900,
                                current_high=61600, candle_tf="5m")
    assert fvg.status != StructureStatus.INVALIDATED
    assert fvg.low_tf_violation_count == 1

def test_fvg_expired_on_zero_strength():
    fvg = FairValueGap(
        fvg_id="fvg4", direction=StructureDirection.BULLISH,
        price_top=62000, price_bottom=61550, timeframe="5m",
        initial_strength=0.1,
    )
    for _ in range(200):
        fvg = update_fvg_lifecycle(fvg, current_close=62500, current_low=62400,
                                    current_high=62600, candle_tf="5m")
    assert fvg.status == StructureStatus.EXPIRED

def test_ob_touched_and_mitigated():
    ob = OrderBlock(
        ob_id="ob1", direction=StructureDirection.BULLISH,
        price_top=61000, price_bottom=60800, timeframe="5m",
    )
    for _ in range(3):
        ob = update_ob_lifecycle(ob, current_close=60950, current_low=60850,
                                  current_high=61050, candle_tf="5m")
    assert ob.status == StructureStatus.MITIGATED

def test_pool_touched():
    pool = LiquidityPool(
        pool_id="lp1", pool_type="equal_low", side="sell_side",
        price_level=61200,
    )
    pool = update_pool_lifecycle(pool, current_low=61100, current_high=61500)
    assert pool.status == PoolStatus.TOUCHED

def test_structure_snapshot_defaults():
    snap = StructureSnapshot()
    assert snap.market_regime == MarketRegime.UNKNOWN
    assert snap.structure_score == 0
    assert len(snap.liquidity_pools) == 0
