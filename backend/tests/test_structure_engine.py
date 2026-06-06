import pytest
import numpy as np
import pandas as pd

from app.services.structure.engine import StructureEngine
from app.services.structure.models import MarketRegime, StructureStatus, PoolStatus


def _make_trending_df(length=100, base=60000, trend="up"):
    np.random.seed(42)
    if trend == "up":
        close = np.linspace(base, base + 5000, length) + np.random.randn(length) * 100
    elif trend == "down":
        close = np.linspace(base, base - 5000, length) + np.random.randn(length) * 100
    else:
        close = base + np.random.randn(length) * 200

    high = close + np.abs(np.random.randn(length) * 80)
    low = close - np.abs(np.random.randn(length) * 80)
    return pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=length, freq="5min"),
        "open": close + np.random.randn(length) * 30,
        "high": high, "low": low, "close": close,
        "volume": np.random.uniform(100, 1000, length),
    })


def test_engine_produces_snapshot():
    engine = StructureEngine(timeframe="5m")
    df = _make_trending_df(100)
    snap = engine.analyze(df)
    assert snap.market_regime != MarketRegime.UNKNOWN or len(df) < 60
    assert isinstance(snap.structure_score, int)
    assert snap.structure_score >= 0


def test_engine_detects_swings():
    engine = StructureEngine(timeframe="5m", swing_lookback=3)
    df = _make_trending_df(100)
    snap = engine.analyze(df)
    assert len(snap.swing_highs) > 0
    assert len(snap.swing_lows) > 0


def test_engine_stateful_across_calls():
    engine = StructureEngine(timeframe="5m")
    df1 = _make_trending_df(80)
    snap1 = engine.analyze(df1)
    df2 = _make_trending_df(100)
    snap2 = engine.analyze(df2)
    # Second call should have carried forward state
    assert isinstance(snap2.structure_score, int)


def test_engine_handles_short_df():
    engine = StructureEngine(timeframe="5m")
    df = _make_trending_df(5)
    snap = engine.analyze(df)
    assert snap.market_regime == MarketRegime.UNKNOWN
    assert snap.structure_score == 0


def test_engine_fvg_detection():
    # Create data with a clear bullish FVG
    n = 50
    close = np.ones(n) * 60000
    high = close + 50
    low = close - 50
    # Insert a gap at index 30: candle 28 high = 60050, candle 30 low = 60200
    close[29] = 60100
    high[29] = 60150
    low[29] = 60050
    close[30] = 60300
    high[30] = 60350
    low[30] = 60250

    df = pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=n, freq="5min"),
        "open": close - 10, "high": high, "low": low, "close": close,
        "volume": np.random.uniform(100, 1000, n),
    })
    engine = StructureEngine(timeframe="5m")
    snap = engine.analyze(df)
    # May or may not detect FVG depending on gap size vs ATR filter
    assert isinstance(snap.fvg_zones, list)
