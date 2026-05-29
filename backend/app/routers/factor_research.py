"""Factor research API endpoints.

Provides cross-sectional factor analysis, multi-factor combination,
Fama-MacBeth regression, and out-of-sample robustness testing.
"""
from __future__ import annotations

from typing import Any, Optional

from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.services.factor_research import (
    FACTOR_REGISTRY,
    CryptoFactorBackend,
    StubFactorBackend,
    combine_factors,
    fama_macbeth_regression,
    out_of_sample_test,
    factor_decay_analysis,
)
from app.services.market_data import market_data_service

router = APIRouter(prefix="/api/factors", tags=["factor-research"])

# Default backend: real market data; falls back to stub on import error
try:
    _backend: Any = CryptoFactorBackend(market_data_service)
except Exception:
    _backend = StubFactorBackend()


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------


class FactorResearchRequest(BaseModel):
    """Run factor research for a single factor across a universe."""
    market: str = "crypto"
    universe: list[str] = Field(
        default=["BTC/USDT", "ETH/USDT", "SOL/USDT", "BNB/USDT", "XRP/USDT"],
        description="List of trading pairs",
    )
    factor_name: str = Field(..., description="Factor name from FACTOR_REGISTRY")
    period: str = Field("3M", description="Lookback period: 1M, 3M, 6M, 1Y")
    forward_days: int = Field(1, ge=1, le=30, description="Forward return horizon in days")


class CombineFactorsRequest(BaseModel):
    """Combine multiple factors into a composite signal."""
    factors: dict[str, dict[str, Any]] = Field(
        ...,
        description="factor_name -> {symbol: series_dict}",
    )
    returns: dict[str, Any] = Field(
        ...,
        description="symbol -> return_series (dict or list)",
    )
    method: str = Field(
        "ic_weight",
        description="Combination method: 'equal_weight' or 'ic_weight'",
    )
    weights: Optional[dict[str, float]] = Field(
        None,
        description="Explicit weights per factor (overrides method)",
    )


class FamaMacBethRequest(BaseModel):
    """Fama-MacBeth two-pass regression."""
    factor_values: dict[str, dict[str, Any]] = Field(
        ...,
        description="factor_name -> {symbol: series_dict}",
    )
    returns: dict[str, Any] = Field(
        ...,
        description="symbol -> return_series",
    )


class RobustnessRequest(BaseModel):
    """Out-of-sample + decay analysis."""
    factor_values: dict[str, Any] = Field(
        ...,
        description="symbol -> factor_series",
    )
    returns: dict[str, Any] = Field(
        ...,
        description="symbol -> return_series",
    )
    train_ratio: float = Field(0.7, ge=0.3, le=0.9, description="Train/test split ratio")
    max_horizon: int = Field(30, ge=1, le=60, description="Max decay horizon in days")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Factor metadata for the registry endpoint
_FACTOR_META: dict[str, dict[str, str]] = {
    "momentum": {"category": "momentum", "description": "Price return over N periods"},
    "momentum_acceleration": {"category": "momentum", "description": "Short momentum minus long momentum"},
    "price_strength": {"category": "momentum", "description": "Fraction of positive return days in window"},
    "realized_volatility": {"category": "volatility", "description": "Annualized std of log returns"},
    "volatility_ratio": {"category": "volatility", "description": "Short-window vol / long-window vol"},
    "downside_volatility": {"category": "volatility", "description": "Std of negative returns only"},
    "volume_momentum": {"category": "volume", "description": "Volume change rate over window"},
    "volume_price_divergence": {"category": "volume", "description": "Price change minus volume change"},
    "vwap_deviation": {"category": "volume", "description": "Distance of price from VWAP"},
    "rsi": {"category": "technical", "description": "RSI normalized to [-1, 1]"},
    "bollinger_position": {"category": "technical", "description": "Position within Bollinger Bands"},
    "macd_signal": {"category": "technical", "description": "MACD histogram normalized by price"},
    "z_score": {"category": "mean_reversion", "description": "Standard z-score relative to rolling mean"},
    "hurst_exponent": {"category": "mean_reversion", "description": "Rolling Hurst exponent (R/S method)"},
    "funding_rate_momentum": {"category": "crypto", "description": "Funding rate trend"},
    "open_interest_change": {"category": "crypto", "description": "Open interest rate of change"},
    "liquidation_pressure": {"category": "crypto", "description": "Net liquidation pressure"},
}


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/research")
async def run_factor_research(body: FactorResearchRequest) -> dict:
    """Run single-factor research across a universe of assets."""
    result = await _backend.research(
        universe=body.universe,
        factor_name=body.factor_name,
        period=body.period,
        forward_days=body.forward_days,
    )
    return {
        "status": result.status,
        "factor_name": result.factor_name,
        "market": result.market,
        "metrics": result.metrics,
        "details": result.details,
    }


@router.get("/list")
async def list_factors() -> dict:
    """List all available factors with metadata."""
    factors = []
    for name in FACTOR_REGISTRY:
        meta = _FACTOR_META.get(name, {"category": "unknown", "description": ""})
        factors.append({
            "name": name,
            "category": meta["category"],
            "description": meta["description"],
        })
    return {"factors": factors, "total": len(factors)}


@router.post("/combine")
async def combine(body: CombineFactorsRequest) -> dict:
    """Combine multiple factors into a composite signal."""
    import pandas as pd

    # Convert nested dicts back to pd.Series
    factors_parsed: dict[str, dict[str, pd.Series]] = {}
    for fname, symbol_data in body.factors.items():
        factors_parsed[fname] = {}
        for sym, series_data in symbol_data.items():
            if isinstance(series_data, dict):
                factors_parsed[fname][sym] = pd.Series(series_data)
            elif isinstance(series_data, list):
                factors_parsed[fname][sym] = pd.Series(series_data)
            else:
                factors_parsed[fname][sym] = pd.Series(series_data)

    returns_parsed: dict[str, pd.Series] = {}
    for sym, series_data in body.returns.items():
        if isinstance(series_data, dict):
            returns_parsed[sym] = pd.Series(series_data)
        elif isinstance(series_data, list):
            returns_parsed[sym] = pd.Series(series_data)
        else:
            returns_parsed[sym] = pd.Series(series_data)

    combined = combine_factors(
        factors=factors_parsed,
        returns=returns_parsed,
        weights=body.weights,
        method=body.method,
    )

    # Serialize back to dicts
    result = {}
    for sym, series in combined.items():
        result[sym] = series.to_dict()

    return {
        "combined": result,
        "method": body.method if body.weights is None else "explicit_weights",
        "symbols": list(combined.keys()),
    }


@router.post("/fama-macbeth")
async def fama_macbeth(body: FamaMacBethRequest) -> dict:
    """Run Fama-MacBeth two-pass cross-sectional regression."""
    import pandas as pd

    factor_values: dict[str, dict[str, pd.Series]] = {}
    for fname, symbol_data in body.factor_values.items():
        factor_values[fname] = {}
        for sym, series_data in symbol_data.items():
            if isinstance(series_data, dict):
                factor_values[fname][sym] = pd.Series(series_data)
            else:
                factor_values[fname][sym] = pd.Series(series_data)

    returns: dict[str, pd.Series] = {}
    for sym, series_data in body.returns.items():
        if isinstance(series_data, dict):
            returns[sym] = pd.Series(series_data)
        else:
            returns[sym] = pd.Series(series_data)

    result = fama_macbeth_regression(factor_values, returns)
    return result


@router.post("/robustness")
async def robustness(body: RobustnessRequest) -> dict:
    """Run out-of-sample test and factor decay analysis."""
    import pandas as pd

    factor_values: dict[str, pd.Series] = {}
    for sym, series_data in body.factor_values.items():
        if isinstance(series_data, dict):
            factor_values[sym] = pd.Series(series_data)
        else:
            factor_values[sym] = pd.Series(series_data)

    returns: dict[str, pd.Series] = {}
    for sym, series_data in body.returns.items():
        if isinstance(series_data, dict):
            returns[sym] = pd.Series(series_data)
        else:
            returns[sym] = pd.Series(series_data)

    oos = out_of_sample_test(
        factor_values=factor_values,
        returns=returns,
        train_ratio=body.train_ratio,
    )

    decay = factor_decay_analysis(
        factor_values=factor_values,
        returns=returns,
        max_horizon=body.max_horizon,
    )

    return {
        "out_of_sample": oos,
        "decay_analysis": decay,
    }
