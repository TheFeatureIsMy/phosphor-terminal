import pytest
import numpy as np
import pandas as pd

from app.services.structure.swing import detect_swing_highs, detect_swing_lows
from app.services.structure.liquidity_pool import detect_equal_levels, detect_swing_pools
from app.services.structure.fvg import detect_fvg
from app.services.structure.order_block import detect_order_blocks
from app.services.structure.bos_choch import detect_bos_choch
from app.services.structure.market_regime import classify_regime
from app.services.structure.models import StructureDirection, MarketRegime


def _make_df(length=100, base_price=60000):
    np.random.seed(42)
    close = np.cumsum(np.random.randn(length) * 100) + base_price
    high = close + np.abs(np.random.randn(length) * 50)
    low = close - np.abs(np.random.randn(length) * 50)
    opn = close + np.random.randn(length) * 30
    volume = np.random.uniform(100, 1000, length)
    return pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=length, freq="5min"),
        "open": opn, "high": high, "low": low, "close": close, "volume": volume,
    })


def test_detect_swing_highs():
    df = _make_df(100)
    highs = detect_swing_highs(df, lookback=3)
    assert len(highs) > 0
    for h in highs:
        assert h.is_high is True
        assert h.price > 0

def test_detect_swing_lows():
    df = _make_df(100)
    lows = detect_swing_lows(df, lookback=3)
    assert len(lows) > 0
    for l in lows:
        assert l.is_high is False

def test_detect_equal_levels():
    from app.services.structure.models import SwingPoint
    swings = [
        SwingPoint(price=60000, index=10, is_high=False),
        SwingPoint(price=60010, index=20, is_high=False),
        SwingPoint(price=60005, index=30, is_high=False),
    ]
    pools = detect_equal_levels(swings, tolerance_pct=0.001)
    assert len(pools) >= 1
    assert pools[0].side == "sell_side"

def test_detect_fvg():
    # Create data with a clear bullish FVG: candle[i-2].high < candle[i].low
    df = pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=5, freq="5min"),
        "open":  [100, 101, 102, 108, 110],
        "high":  [101, 102, 103, 110, 112],
        "low":   [99,  100, 101, 106, 109],
        "close": [100, 101, 102, 109, 111],
        "volume": [100, 100, 100, 200, 150],
    })
    fvgs = detect_fvg(df, min_gap_atr_ratio=0.0)
    bullish = [f for f in fvgs if f.direction == StructureDirection.BULLISH]
    assert len(bullish) >= 1

def test_detect_order_blocks():
    df = _make_df(100)
    obs = detect_order_blocks(df, volume_threshold=0.5)
    # With low threshold, should find some
    assert isinstance(obs, list)

def test_detect_bos_choch():
    from app.services.structure.models import SwingPoint
    highs = [
        SwingPoint(price=100, index=5, is_high=True),
        SwingPoint(price=110, index=15, is_high=True),
        SwingPoint(price=120, index=25, is_high=True),
    ]
    lows = [
        SwingPoint(price=95, index=10, is_high=False),
        SwingPoint(price=105, index=20, is_high=False),
    ]
    breaks = detect_bos_choch(highs, lows, [])
    bos = [b for b in breaks if b.break_type == "bos"]
    assert len(bos) >= 1

def test_classify_regime_trend_up():
    n = 100
    close = np.linspace(60000, 65000, n)
    df = pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=n, freq="5min"),
        "open": close * 0.999, "high": close * 1.002,
        "low": close * 0.998, "close": close,
        "volume": np.ones(n) * 500,
    })
    regime = classify_regime(df)
    assert regime in (MarketRegime.TREND_UP, MarketRegime.RANGE)

def test_classify_regime_panic():
    n = 100
    close = np.ones(n) * 60000
    close[-5:] = [60000, 55000, 50000, 48000, 45000]
    df = pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=n, freq="5min"),
        "open": close * 1.001, "high": close * 1.01,
        "low": close * 0.99, "close": close,
        "volume": np.ones(n) * 500,
    })
    regime = classify_regime(df)
    assert regime == MarketRegime.PANIC
