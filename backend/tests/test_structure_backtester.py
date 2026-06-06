import pytest
import numpy as np
import pandas as pd

from app.services.structure_backtester import StructureBacktester, StructureBacktestResult


def _make_volatile_df(length=200, base=60000):
    """Create data with enough volatility to generate structure events."""
    np.random.seed(42)
    # Create a mean-reverting series with occasional spikes
    close = np.zeros(length)
    close[0] = base
    for i in range(1, length):
        shock = np.random.randn() * 150
        if np.random.rand() < 0.05:  # 5% chance of big move
            shock *= 5
        close[i] = close[i - 1] + shock

    high = close + np.abs(np.random.randn(length) * 80)
    low = close - np.abs(np.random.randn(length) * 80)

    return pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=length, freq="5min"),
        "open": close + np.random.randn(length) * 30,
        "high": high,
        "low": low,
        "close": close,
        "volume": np.random.uniform(100, 2000, length),
    })


def _make_trending_df(length=200, base=60000):
    """Clear uptrend followed by reversal — should generate sweeps."""
    np.random.seed(123)
    close = np.zeros(length)
    close[0] = base
    for i in range(1, length // 2):
        close[i] = close[i - 1] + np.random.uniform(10, 100)
    for i in range(length // 2, length):
        close[i] = close[i - 1] - np.random.uniform(10, 100)

    high = close + np.abs(np.random.randn(length) * 60)
    low = close - np.abs(np.random.randn(length) * 60)

    return pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=length, freq="5min"),
        "open": close + np.random.randn(length) * 20,
        "high": high,
        "low": low,
        "close": close,
        "volume": np.random.uniform(100, 2000, length),
    })


def test_backtester_runs_without_error():
    bt = StructureBacktester(timeframe="5m")
    df = _make_volatile_df(200)
    result = bt.run(df)
    assert isinstance(result, StructureBacktestResult)
    assert result.total_bars == 200


def test_backtester_short_df():
    bt = StructureBacktester(timeframe="5m")
    df = _make_volatile_df(30)
    result = bt.run(df)
    assert result.total_bars == 30
    assert result.total_events == 0


def test_backtester_has_regime_distribution():
    bt = StructureBacktester(timeframe="5m")
    df = _make_volatile_df(200)
    result = bt.run(df)
    assert len(result.regime_distribution) > 0
    total_regime = sum(result.regime_distribution.values())
    assert total_regime > 0


def test_backtester_event_stats_structure():
    bt = StructureBacktester(timeframe="5m")
    df = _make_trending_df(200)
    result = bt.run(df)
    for event_type, stats in result.event_stats.items():
        assert stats.total_count > 0
        assert 0.0 <= stats.success_rate <= 1.0
        assert len(stats.avg_forward_return) > 0


def test_backtester_outcomes_have_forward_returns():
    bt = StructureBacktester(timeframe="5m", forward_bars=[5, 10])
    df = _make_volatile_df(200)
    result = bt.run(df)
    for outcome in result.outcomes:
        assert 5 in outcome.forward_returns or 10 in outcome.forward_returns
        assert outcome.regime != ""
        assert outcome.event_type != ""


def test_backtester_regime_breakdown():
    bt = StructureBacktester(timeframe="5m")
    df = _make_trending_df(200)
    result = bt.run(df)
    for stats in result.event_stats.values():
        if stats.by_regime:
            for regime_name, regime_data in stats.by_regime.items():
                assert "count" in regime_data
                assert "success" in regime_data
                assert "rate" in regime_data
                assert regime_data["count"] > 0


def test_backtester_custom_forward_bars():
    bt = StructureBacktester(timeframe="5m", forward_bars=[3, 7, 15])
    df = _make_volatile_df(200)
    result = bt.run(df)
    for outcome in result.outcomes:
        for bars in outcome.forward_returns:
            assert bars in (3, 7, 15)


def test_backtester_detects_events_on_trending_data():
    """Trending data with a reversal should produce at least some events."""
    bt = StructureBacktester(timeframe="5m")
    df = _make_trending_df(300)
    result = bt.run(df)
    # With 300 bars of clear trend + reversal, we expect structure events
    assert result.total_events > 0
    assert len(result.outcomes) > 0


def test_backtester_regime_distribution_covers_all_bars():
    bt = StructureBacktester(timeframe="5m")
    df = _make_volatile_df(200)
    result = bt.run(df)
    total = sum(result.regime_distribution.values())
    assert total == 200
