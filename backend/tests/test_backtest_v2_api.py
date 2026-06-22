import pytest
from pydantic import ValidationError
from app.schemas.backtest_v2 import StartBacktestRequest


def test_slippage_bps_default_none():
    req = StartBacktestRequest(
        dsl={"version": "2.5"},
        timerange="20240101-20240601",
        symbols=["BTC/USDT"],
    )
    assert req.slippage_bps is None


def test_slippage_bps_accepts_valid():
    req = StartBacktestRequest(
        dsl={"version": "2.5"},
        timerange="20240101-20240601",
        symbols=["BTC/USDT"],
        slippage_bps=5.0,
    )
    assert req.slippage_bps == 5.0


def test_slippage_bps_rejects_negative():
    with pytest.raises(ValidationError):
        StartBacktestRequest(
            dsl={"version": "2.5"},
            timerange="20240101-20240601",
            symbols=["BTC/USDT"],
            slippage_bps=-1.0,
        )


def test_slippage_bps_rejects_over_100():
    with pytest.raises(ValidationError):
        StartBacktestRequest(
            dsl={"version": "2.5"},
            timerange="20240101-20240601",
            symbols=["BTC/USDT"],
            slippage_bps=101.0,
        )
