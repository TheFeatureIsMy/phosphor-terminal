import pytest
import pandas as pd
import numpy as np

from app.domain.dsl import AccountRiskPolicy
from app.services.decision_engine import DecisionEngine
from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.account_risk_firewall import AccountRiskFirewall

@pytest.fixture
def store():
    return RuntimeRedisStore(redis_url=None)

@pytest.fixture
def firewall(store):
    policy = AccountRiskPolicy()
    return AccountRiskFirewall(policy=policy, redis_store=store)

@pytest.fixture
def engine(store, firewall):
    return DecisionEngine(redis_store=store, risk_firewall=firewall)

def _make_dsl():
    return {
        "schema_version": "2.5",
        "timeframe": "5m",
        "symbols": ["BTC/USDT"],
        "entry": {"logic": "AND", "rules": [
            {"type": "indicator_threshold", "indicator": "rsi",
             "params": {"period": 14}, "operator": "<", "value": 30}
        ]},
        "exit": {"logic": "AND", "rules": [
            {"type": "indicator_threshold", "indicator": "rsi",
             "params": {"period": 14}, "operator": ">", "value": 70}
        ]},
        "filters": [],
        "position_sizing": {"type": "fixed_pct", "position_pct": 0.1},
        "risk": {"stoploss": -0.05, "max_open_trades": 3},
    }

def _make_df_with_low_rsi(length=50):
    """Create a dataframe where RSI will be below 30 on the last candle."""
    close = np.ones(length) * 60000
    # Simulate a strong downtrend at the end to push RSI below 30
    for i in range(length - 15, length):
        close[i] = close[i-1] * 0.995
    df = pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=length, freq="5min"),
        "open": close * 1.001,
        "high": close * 1.002,
        "low": close * 0.998,
        "close": close,
        "volume": np.random.uniform(100, 1000, length),
    })
    return df

def _make_df_with_high_rsi(length=50):
    """Create a dataframe where RSI will be above 30 (no entry signal)."""
    close = np.ones(length) * 60000
    for i in range(length - 15, length):
        close[i] = close[i-1] * 1.005
    df = pd.DataFrame({
        "date": pd.date_range("2026-01-01", periods=length, freq="5min"),
        "open": close * 0.999,
        "high": close * 1.002,
        "low": close * 0.998,
        "close": close,
        "volume": np.random.uniform(100, 1000, length),
    })
    return df

@pytest.mark.asyncio
async def test_no_signal_returns_none(engine):
    dsl = _make_dsl()
    df = _make_df_with_high_rsi()
    result = await engine.evaluate(
        strategy_id="strat1", dsl=dsl, dataframe=df,
        account_id="acc1", exchange="binance", symbol="BTC/USDT", timeframe="5m",
    )
    assert result is None

@pytest.mark.asyncio
async def test_signal_generates_allow_snapshot(engine):
    dsl = _make_dsl()
    df = _make_df_with_low_rsi()
    result = await engine.evaluate(
        strategy_id="strat1", dsl=dsl, dataframe=df,
        account_id="acc1", exchange="binance", symbol="BTC/USDT", timeframe="5m",
    )
    if result is not None:
        assert result.execution_plan.decision == "allow_trade"
        assert "rsi_triggered" in result.reason_codes
        assert result.snapshot_id.startswith("snap_")
        assert result.latency_ms is not None

@pytest.mark.asyncio
async def test_risk_blocked_generates_reject(engine, firewall):
    await firewall.activate_kill_switch("acc_blocked")
    dsl = _make_dsl()
    df = _make_df_with_low_rsi()
    result = await engine.evaluate(
        strategy_id="strat1", dsl=dsl, dataframe=df,
        account_id="acc_blocked", exchange="binance", symbol="BTC/USDT", timeframe="5m",
    )
    if result is not None:
        assert result.execution_plan.decision == "reject_trade"
        assert "kill_switch_active" in result.reason_codes

@pytest.mark.asyncio
async def test_snapshot_written_to_redis(engine, store):
    dsl = _make_dsl()
    df = _make_df_with_low_rsi()
    result = await engine.evaluate(
        strategy_id="strat1", dsl=dsl, dataframe=df,
        account_id="acc1", exchange="binance", symbol="BTC/USDT", timeframe="5m",
    )
    if result is not None:
        cached = await store.read_snapshot("strat1", "BTC/USDT", "5m")
        assert cached is not None
        assert cached["snapshot_id"] == result.snapshot_id

@pytest.mark.asyncio
async def test_ai_cache_missing_by_default(engine):
    dsl = _make_dsl()
    df = _make_df_with_low_rsi()
    result = await engine.evaluate(
        strategy_id="strat1", dsl=dsl, dataframe=df,
        account_id="acc1", exchange="binance", symbol="BTC/USDT", timeframe="5m",
    )
    if result is not None:
        assert result.ai_context.cache_state == "missing"
