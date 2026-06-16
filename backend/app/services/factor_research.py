"""Market-aware factor research system for crypto quant trading.

Provides 15+ factor functions across 6 categories (momentum, volatility,
volume, technical, mean reversion, crypto-specific), plus cross-sectional
IC/Rank-IC analysis, long-short portfolio construction, turnover measurement,
and factor combination utilities.

Academic thresholds (BARRA/MSCI, Grinold & Kahn):
- IC mean > 0.03  = valid signal
- IC_IR > 0.5     = consistent signal
- Rank IC > 0.04  = valid (non-parametric)
- Long-short Sharpe > 1.0 = good
- Turnover < 0.3  = low cost
"""
from __future__ import annotations

import math
import warnings
from dataclasses import dataclass, field
from typing import Any, Callable

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MIN_UNIVERSE_SIZE = 10  # Minimum assets per date for cross-sectional IC
TRADING_DAYS_PER_YEAR = 365  # Crypto trades 24/7

# ---------------------------------------------------------------------------
# Factor Functions
# ---------------------------------------------------------------------------

# --- Momentum (3) ---


def momentum(close: pd.Series, window: int = 20) -> pd.Series:
    """Price return over N periods."""
    return close.pct_change(window)


def momentum_acceleration(
    close: pd.Series, short: int = 5, long: int = 20
) -> pd.Series:
    """Short momentum minus long momentum — measures trend acceleration."""
    return momentum(close, short) - momentum(close, long)


def price_strength(close: pd.Series, window: int = 20) -> pd.Series:
    """Fraction of positive return days within a rolling window."""
    rets = close.pct_change()
    return rets.rolling(window).apply(lambda x: (x > 0).sum() / len(x), raw=True)


# --- Volatility (3) ---


def realized_volatility(close: pd.Series, window: int = 20) -> pd.Series:
    """Annualized standard deviation of log returns."""
    log_rets = np.log(close / close.shift(1))
    return log_rets.rolling(window).std() * math.sqrt(TRADING_DAYS_PER_YEAR)


def volatility_ratio(
    close: pd.Series, short: int = 5, long: int = 20
) -> pd.Series:
    """Short-window volatility divided by long-window volatility."""
    short_vol = realized_volatility(close, short)
    long_vol = realized_volatility(close, long)
    return short_vol / long_vol.replace(0, np.nan)


def downside_volatility(close: pd.Series, window: int = 20) -> pd.Series:
    """Standard deviation of negative returns only (semi-deviation)."""
    rets = close.pct_change()
    neg_rets = rets.where(rets < 0, 0.0)
    return neg_rets.rolling(window).std() * math.sqrt(TRADING_DAYS_PER_YEAR)


# --- Volume (3) ---


def volume_momentum(volume: pd.Series, window: int = 10) -> pd.Series:
    """Volume change rate over rolling window."""
    return volume.pct_change(window)


def volume_price_divergence(
    close: pd.Series, volume: pd.Series, window: int = 20
) -> pd.Series:
    """Price change minus volume change — divergence signals potential reversals."""
    price_chg = close.pct_change(window)
    vol_chg = volume.pct_change(window)
    return price_chg - vol_chg


def vwap_deviation(
    close: pd.Series, volume: pd.Series, window: int = 20
) -> pd.Series:
    """Distance of price from volume-weighted average price."""
    vwap = (close * volume).rolling(window).sum() / volume.rolling(window).sum()
    return (close - vwap) / vwap.replace(0, np.nan)


# --- Technical (3) ---


def rsi(close: pd.Series, period: int = 14) -> pd.Series:
    """RSI normalized to [-1, 1] range. 0 = neutral, +1 = overbought, -1 = oversold."""
    delta = close.diff()
    gain = delta.where(delta > 0, 0.0).rolling(period).mean()
    loss = (-delta.where(delta < 0, 0.0)).rolling(period).mean()
    # Clip loss to avoid division by zero (all-gains edge case -> RSI = 100)
    rs = gain / loss.clip(lower=1e-10)
    rsi_val = 100 - (100 / (1 + rs))
    # Normalize from [0, 100] to [-1, 1]
    return (rsi_val - 50) / 50


def bollinger_position(
    close: pd.Series, window: int = 20, num_std: float = 2.0
) -> pd.Series:
    """Position within Bollinger Bands normalized to [-1, 1]."""
    sma = close.rolling(window).mean()
    std = close.rolling(window).std()
    upper = sma + num_std * std
    lower = sma - num_std * std
    band_width = (upper - lower).replace(0, np.nan)
    return 2 * (close - lower) / band_width - 1


def macd_signal(
    close: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9
) -> pd.Series:
    """MACD histogram normalized by price."""
    ema_fast = close.ewm(span=fast, adjust=False).mean()
    ema_slow = close.ewm(span=slow, adjust=False).mean()
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal, adjust=False).mean()
    histogram = macd_line - signal_line
    return histogram / close.replace(0, np.nan)


# --- Mean Reversion (2) ---


def z_score(close: pd.Series, window: int = 20) -> pd.Series:
    """Standard z-score of price relative to rolling mean."""
    sma = close.rolling(window).mean()
    std = close.rolling(window).std()
    return (close - sma) / std.replace(0, np.nan)


def hurst_exponent(close: pd.Series, window: int = 100) -> pd.Series:
    """Rolling Hurst exponent estimate.

    <0.5 = mean-reverting, 0.5 = random walk, >0.5 = trending.
    Uses R/S (rescaled range) method.
    """
    log_prices = np.log(close.replace(0, np.nan))

    def _hurst_rs(series: np.ndarray) -> float:
        n = len(series)
        if n < 10:
            return 0.5
        mean = np.mean(series)
        deviations = series - mean
        cumulative = np.cumsum(deviations)
        r = np.max(cumulative) - np.min(cumulative)
        s = np.std(series, ddof=1)
        if s == 0 or r == 0:
            return 0.5
        return math.log(r / s) / math.log(n)

    return log_prices.rolling(window, min_periods=max(20, window // 2)).apply(
        _hurst_rs, raw=True
    )


# --- Crypto-Specific (3) ---


def funding_rate_momentum(
    funding_rates: pd.Series, window: int = 8
) -> pd.Series:
    """Funding rate trend — rising positive funding = crowded long."""
    return funding_rates.rolling(window).mean()


def open_interest_change(
    open_interest: pd.Series, window: int = 24
) -> pd.Series:
    """Open interest rate of change."""
    return open_interest.pct_change(window)


def liquidation_pressure(
    long_liqs: pd.Series, short_liqs: pd.Series, window: int = 24
) -> pd.Series:
    """Net liquidation pressure: long liquidations minus short liquidations,
    smoothed over window. Positive = longs being squeezed."""
    net = long_liqs - short_liqs
    return net.rolling(window).mean()


# ---------------------------------------------------------------------------
# Factor Registry
# ---------------------------------------------------------------------------

FACTOR_REGISTRY: dict[str, Callable[..., pd.Series]] = {
    # Momentum
    "momentum": momentum,
    "momentum_acceleration": momentum_acceleration,
    "price_strength": price_strength,
    # Volatility
    "realized_volatility": realized_volatility,
    "volatility_ratio": volatility_ratio,
    "downside_volatility": downside_volatility,
    # Volume
    "volume_momentum": volume_momentum,
    "volume_price_divergence": volume_price_divergence,
    "vwap_deviation": vwap_deviation,
    # Technical
    "rsi": rsi,
    "bollinger_position": bollinger_position,
    "macd_signal": macd_signal,
    # Mean Reversion
    "z_score": z_score,
    "hurst_exponent": hurst_exponent,
    # Crypto-Specific
    "funding_rate_momentum": funding_rate_momentum,
    "open_interest_change": open_interest_change,
    "liquidation_pressure": liquidation_pressure,
}

# Maps factor name to the columns it needs from OHLCV data.
# "close" is always available; "volume" needs the volume column;
# "ohlcv" means the factor takes separate close/volume series.
_FACTOR_INPUTS: dict[str, list[str]] = {
    "momentum": ["close"],
    "momentum_acceleration": ["close"],
    "price_strength": ["close"],
    "realized_volatility": ["close"],
    "volatility_ratio": ["close"],
    "downside_volatility": ["close"],
    "volume_momentum": ["volume"],
    "volume_price_divergence": ["close", "volume"],
    "vwap_deviation": ["close", "volume"],
    "rsi": ["close"],
    "bollinger_position": ["close"],
    "macd_signal": ["close"],
    "z_score": ["close"],
    "hurst_exponent": ["close"],
    "funding_rate_momentum": ["funding_rates"],
    "open_interest_change": ["open_interest"],
    "liquidation_pressure": ["long_liqs", "short_liqs"],
}


# ---------------------------------------------------------------------------
# Cross-Sectional Analysis
# ---------------------------------------------------------------------------


def cross_sectional_ic(
    factor_values: dict[str, pd.Series],
    returns: dict[str, pd.Series],
) -> pd.Series:
    """Compute daily cross-sectional Pearson IC between factor values and next-day returns.

    For each date, correlate factor values across all assets with their
    forward returns.  Requires at least MIN_UNIVERSE_SIZE assets per date.

    Parameters
    ----------
    factor_values : dict mapping symbol -> factor Series (indexed by date)
    returns : dict mapping symbol -> forward return Series (indexed by date)

    Returns
    -------
    pd.Series of daily IC values indexed by date.
    """
    # Build aligned DataFrames
    fv_df = pd.DataFrame(factor_values)
    ret_df = pd.DataFrame(returns)
    # Align on common dates
    common_dates = fv_df.index.intersection(ret_df.index)
    fv_df = fv_df.loc[common_dates]
    ret_df = ret_df.loc[common_dates]

    ic_values = {}
    for date in common_dates:
        fv_row = fv_df.loc[date].dropna()
        ret_row = ret_df.loc[date].dropna()
        common_syms = fv_row.index.intersection(ret_row.index)
        if len(common_syms) < MIN_UNIVERSE_SIZE:
            continue
        fv_vals = fv_row[common_syms].astype(float)
        ret_vals = ret_row[common_syms].astype(float)
        if fv_vals.std() == 0 or ret_vals.std() == 0:
            ic_values[date] = 0.0
        else:
            ic_values[date] = float(fv_vals.corr(ret_vals))

    return pd.Series(ic_values, name="ic")


def cross_sectional_rank_ic(
    factor_values: dict[str, pd.Series],
    returns: dict[str, pd.Series],
) -> pd.Series:
    """Compute daily cross-sectional Spearman (rank) IC.

    Same as cross_sectional_ic but uses rank correlation.
    """
    # Try scipy first for speed
    try:
        from scipy.stats import spearmanr as _spearmanr

        def _rank_corr(a: np.ndarray, b: np.ndarray) -> float:
            corr, _ = _spearmanr(a, b)
            return float(corr) if not math.isnan(corr) else 0.0

    except ImportError:
        # Pure pandas fallback
        def _rank_corr(a: np.ndarray, b: np.ndarray) -> float:
            s1 = pd.Series(a).rank()
            s2 = pd.Series(b).rank()
            return float(s1.corr(s2))

    fv_df = pd.DataFrame(factor_values)
    ret_df = pd.DataFrame(returns)
    common_dates = fv_df.index.intersection(ret_df.index)
    fv_df = fv_df.loc[common_dates]
    ret_df = ret_df.loc[common_dates]

    ic_values = {}
    for date in common_dates:
        fv_row = fv_df.loc[date].dropna()
        ret_row = ret_df.loc[date].dropna()
        common_syms = fv_row.index.intersection(ret_row.index)
        if len(common_syms) < MIN_UNIVERSE_SIZE:
            continue
        fv_vals = fv_row[common_syms].astype(float).values
        ret_vals = ret_row[common_syms].astype(float).values
        ic_values[date] = _rank_corr(fv_vals, ret_vals)

    return pd.Series(ic_values, name="rank_ic")


def long_short_returns(
    factor_values: dict[str, pd.Series],
    returns: dict[str, pd.Series],
    quantile: float = 0.2,
) -> pd.Series:
    """Daily long-short portfolio return.

    Each date: rank assets by factor, go long top quantile, short bottom
    quantile, compute equal-weighted spread return.
    """
    fv_df = pd.DataFrame(factor_values)
    ret_df = pd.DataFrame(returns)
    common_dates = fv_df.index.intersection(ret_df.index)
    fv_df = fv_df.loc[common_dates]
    ret_df = ret_df.loc[common_dates]

    ls_returns = {}
    for date in common_dates:
        fv_row = fv_df.loc[date].dropna()
        ret_row = ret_df.loc[date].dropna()
        common_syms = fv_row.index.intersection(ret_row.index)
        if len(common_syms) < MIN_UNIVERSE_SIZE:
            continue
        fv_sorted = fv_row[common_syms].sort_values()
        n_long = max(1, int(len(fv_sorted) * quantile))
        bottom = fv_sorted.index[:n_long]
        top = fv_sorted.index[-n_long:]
        long_ret = float(ret_row[top].mean())
        short_ret = float(ret_row[bottom].mean())
        ls_returns[date] = long_ret - short_ret

    return pd.Series(ls_returns, name="long_short_return")


def portfolio_turnover(
    factor_values: dict[str, pd.Series],
    quantile: float = 0.2,
) -> pd.Series:
    """Daily portfolio turnover — fraction of portfolio that changes.

    Measures how stable the long/short legs are across consecutive days.
    """
    fv_df = pd.DataFrame(factor_values)
    dates = sorted(fv_df.index)

    prev_long: set[str] = set()
    prev_short: set[str] = set()
    turnover = {}

    for date in dates:
        row = fv_df.loc[date].dropna()
        if len(row) < MIN_UNIVERSE_SIZE:
            continue
        sorted_syms = row.sort_values()
        n = max(1, int(len(sorted_syms) * quantile))
        current_short = set(sorted_syms.index[:n])
        current_long = set(sorted_syms.index[-n:])

        if prev_long or prev_short:
            # Use difference (items entering the portfolio) so turnover is in [0, 1]
            long_enter = len(current_long.difference(prev_long))
            short_enter = len(current_short.difference(prev_short))
            total = len(current_long) + len(current_short)
            turnover[date] = (long_enter + short_enter) / total if total > 0 else 0.0

        prev_long = current_long
        prev_short = current_short

    return pd.Series(turnover, name="turnover")


# ---------------------------------------------------------------------------
# Factor Combination
# ---------------------------------------------------------------------------


def combine_factors(
    factors: dict[str, dict[str, pd.Series]],
    returns: dict[str, pd.Series],
    weights: dict[str, float] | None = None,
    method: str = "equal_weight",
) -> dict[str, pd.Series]:
    """Combine multiple factors into a composite signal.

    Parameters
    ----------
    factors : dict of factor_name -> {symbol: factor_series}
    returns : dict of symbol -> return_series (used for IC weighting)
    weights : explicit weights (overrides method if provided)
    method : "equal_weight" or "ic_weight"

    Returns
    -------
    dict mapping symbol -> combined factor series
    """
    factor_names = list(factors.keys())
    if not factor_names:
        return {}

    # Determine weights
    if weights is not None:
        w = weights
    elif method == "ic_weight":
        w = {}
        for fname, fvals in factors.items():
            ic = cross_sectional_ic(fvals, returns)
            w[fname] = abs(float(ic.mean())) if len(ic) > 0 else 0.0
        total_w = sum(w.values())
        if total_w > 0:
            w = {k: v / total_w for k, v in w.items()}
        else:
            w = {fname: 1.0 / len(factor_names) for fname in factor_names}
    else:
        # equal_weight
        w = {fname: 1.0 / len(factor_names) for fname in factor_names}

    # Collect all symbols
    all_symbols: set[str] = set()
    for fvals in factors.values():
        all_symbols.update(fvals.keys())

    # Build combined series per symbol
    combined: dict[str, pd.Series] = {}
    for sym in all_symbols:
        parts = []
        for fname in factor_names:
            if sym in factors[fname]:
                s = factors[fname][sym].copy()
                # Z-score normalization per factor before weighting
                mu = s.mean()
                sigma = s.std()
                if sigma > 0:
                    s = (s - mu) / sigma
                parts.append(s * w.get(fname, 0.0))
        if parts:
            combined[sym] = sum(parts)

    return combined


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass
class FactorResult:
    """Result of a factor research run."""

    status: str
    factor_name: str
    market: str
    metrics: dict[str, Any] = field(default_factory=dict)
    details: dict[str, Any] = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Period utility
# ---------------------------------------------------------------------------

_PERIOD_DAYS: dict[str, int] = {
    "1M": 30,
    "3M": 90,
    "6M": 180,
    "1Y": 365,
}


def _period_to_limit(period: str, timeframe: str = "1d") -> int:
    """Convert a period string to a data limit (number of bars)."""
    days = _PERIOD_DAYS.get(period.upper(), 90)
    tf_hours = {"1h": 1, "4h": 4, "1d": 24, "1w": 168}
    hours = tf_hours.get(timeframe, 24)
    return max(days * 24 // hours, 50)


# ---------------------------------------------------------------------------
# Stub Factor Backend (deterministic fallback)
# ---------------------------------------------------------------------------


def _emit_deprecation_warning():
    """Emit a deprecation warning compatible with Python 3.9+.

    `warnings.deprecated` decorator is Python 3.13+ only; we use a manual
    class-level warning to stay compatible with the project's Python 3.11 target.
    """
    warnings.warn(
        "StubFactorBackend is deprecated (v2.5 mock-removal). "
        "Routers no longer use it; it remains only for legacy test fixtures.",
        DeprecationWarning,
        stacklevel=2,
    )


class StubFactorBackend:
    """Deterministic fallback when market data is unavailable.

    DEPRECATED (v2.5 mock-removal): No longer used by routers. Routers now
    raise HTTPException 503 on CryptoFactorBackend init failure instead of
    silently falling back to this stub. Kept for test compatibility.

    Produces plausible-looking but synthetic metrics so the UI can still render.
    """

    def __init__(self) -> None:
        self.factor_registry = dict(FACTOR_REGISTRY)

    async def research(
        self,
        universe: list[str],
        factor_name: str,
        period: str = "3M",
        forward_days: int = 1,
    ) -> FactorResult:
        if factor_name not in self.factor_registry:
            return FactorResult(
                status="error",
                factor_name=factor_name,
                market="crypto",
                metrics={"error": f"Unknown factor: {factor_name}"},
            )

        # Deterministic pseudo-random from factor name
        seed = sum(ord(c) for c in factor_name) % 1000
        rng = np.random.RandomState(seed)

        ic_mean = 0.02 + rng.uniform(0, 0.06)
        ic_std = 0.08 + rng.uniform(0, 0.12)
        ic_ir = ic_mean / ic_std if ic_std > 0 else 0
        rank_ic = ic_mean * (1.0 + rng.uniform(-0.2, 0.4))
        ls_sharpe = rng.uniform(0.3, 2.5)
        turnover = rng.uniform(0.1, 0.6)

        return FactorResult(
            status="ok_stub",
            factor_name=factor_name,
            market="crypto",
            metrics={
                "ic_mean": round(ic_mean, 4),
                "ic_std": round(ic_std, 4),
                "ic_ir": round(ic_ir, 4),
                "rank_ic_mean": round(rank_ic, 4),
                "long_short_sharpe": round(ls_sharpe, 4),
                "turnover_mean": round(turnover, 4),
                "ic_valid": ic_mean > 0.03,
                "ic_ir_valid": ic_ir > 0.5,
                "rank_ic_valid": rank_ic > 0.04,
                "sharpe_valid": ls_sharpe > 1.0,
                "turnover_valid": turnover < 0.3,
            },
            details={
                "universe_size": len(universe),
                "period": period,
                "forward_days": forward_days,
                "source": "stub",
            },
        )


# ---------------------------------------------------------------------------
# CryptoFactorBackend (real factor research)
# ---------------------------------------------------------------------------


class CryptoFactorBackend:
    """Full factor research engine backed by market data.

    Fetches OHLCV data for a universe of symbols, computes the requested
    factor, then evaluates IC, Rank-IC, long-short returns, and turnover.
    """

    def __init__(self, market_data_service: Any) -> None:
        self.market_data = market_data_service
        self.factor_registry: dict[str, Callable[..., pd.Series]] = dict(
            FACTOR_REGISTRY
        )

    async def research(
        self,
        universe: list[str],
        factor_name: str,
        period: str = "3M",
        forward_days: int = 1,
    ) -> FactorResult:
        if factor_name not in self.factor_registry:
            return FactorResult(
                status="error",
                factor_name=factor_name,
                market="crypto",
                metrics={"error": f"Unknown factor: {factor_name}"},
            )

        try:
            # 1. Fetch OHLCV for all symbols
            limit = _period_to_limit(period)
            ohlcv_map: dict[str, pd.DataFrame] = {}
            for sym in universe:
                data = await self.market_data.get_ohlcv(sym, "1d", limit)
                if data and len(data) > 20:
                    df = pd.DataFrame(data)
                    if "timestamp" in df.columns:
                        df["date"] = pd.to_datetime(df["timestamp"], unit="ms")
                        df = df.set_index("date")
                    ohlcv_map[sym] = df

            if len(ohlcv_map) < MIN_UNIVERSE_SIZE:
                return FactorResult(
                    status="insufficient_data",
                    factor_name=factor_name,
                    market="crypto",
                    metrics={
                        "error": f"Only {len(ohlcv_map)} symbols had data (need {MIN_UNIVERSE_SIZE})"
                    },
                )

            # 2. Compute factor values and forward returns
            factor_func = self.factor_registry[factor_name]
            inputs = _FACTOR_INPUTS.get(factor_name, ["close"])

            factor_values: dict[str, pd.Series] = {}
            forward_returns: dict[str, pd.Series] = {}

            for sym, df in ohlcv_map.items():
                close = df["close"]
                # Build kwargs based on what the factor needs
                kwargs: dict[str, pd.Series] = {}
                for col in inputs:
                    if col in df.columns:
                        kwargs[col] = df[col]
                    else:
                        # Crypto-specific columns may not be in OHLCV;
                        # skip this symbol for crypto-specific factors
                        break
                else:
                    try:
                        fv = factor_func(**kwargs)
                        # Drop NaN from factor computation
                        fv = fv.dropna()
                        if len(fv) > 10:
                            factor_values[sym] = fv
                            # Forward returns
                            fwd = close.pct_change(forward_days).shift(-forward_days)
                            forward_returns[sym] = fwd
                    except Exception:
                        continue

            if len(factor_values) < MIN_UNIVERSE_SIZE:
                return FactorResult(
                    status="insufficient_data",
                    factor_name=factor_name,
                    market="crypto",
                    metrics={
                        "error": f"Only {len(factor_values)} symbols computed factor (need {MIN_UNIVERSE_SIZE})"
                    },
                )

            # 3. Compute analytics
            ic_series = cross_sectional_ic(factor_values, forward_returns)
            rank_ic_series = cross_sectional_rank_ic(factor_values, forward_returns)
            ls_rets = long_short_returns(factor_values, forward_returns)
            to_series = portfolio_turnover(factor_values)

            # 4. Aggregate metrics
            def _safe_stats(s: pd.Series) -> tuple[float, float]:
                if len(s) == 0:
                    return 0.0, 0.0
                return float(s.mean()), float(s.std())

            ic_mean, ic_std = _safe_stats(ic_series)
            rank_ic_mean, rank_ic_std = _safe_stats(rank_ic_series)
            ls_mean, ls_std = _safe_stats(ls_rets)
            to_mean, _ = _safe_stats(to_series)

            ic_ir = ic_mean / ic_std if ic_std > 0 else 0.0
            ls_sharpe = (ls_mean / ls_std * math.sqrt(TRADING_DAYS_PER_YEAR)) if ls_std > 0 else 0.0

            return FactorResult(
                status="ok",
                factor_name=factor_name,
                market="crypto",
                metrics={
                    "ic_mean": round(ic_mean, 4),
                    "ic_std": round(ic_std, 4),
                    "ic_ir": round(ic_ir, 4),
                    "rank_ic_mean": round(rank_ic_mean, 4),
                    "rank_ic_std": round(rank_ic_std, 4),
                    "long_short_sharpe": round(ls_sharpe, 4),
                    "long_short_mean_return": round(ls_mean, 6),
                    "turnover_mean": round(to_mean, 4),
                    "ic_valid": ic_mean > 0.03,
                    "ic_ir_valid": ic_ir > 0.5,
                    "rank_ic_valid": rank_ic_mean > 0.04,
                    "sharpe_valid": ls_sharpe > 1.0,
                    "turnover_valid": to_mean < 0.3,
                    "universe_size": len(factor_values),
                    "observation_days": len(ic_series),
                },
                details={
                    "ic_series": ic_series.to_dict(),
                    "rank_ic_series": rank_ic_series.to_dict(),
                    "long_short_returns": ls_rets.to_dict(),
                    "turnover": to_series.to_dict(),
                    "factor_values_latest": {
                        sym: float(vals.iloc[-1]) if len(vals) > 0 else 0.0
                        for sym, vals in factor_values.items()
                    },
                },
            )

        except Exception as exc:
            return FactorResult(
                status="error",
                factor_name=factor_name,
                market="crypto",
                metrics={"error": str(exc)},
            )


# ---------------------------------------------------------------------------
# Advanced Factor Testing
# ---------------------------------------------------------------------------


def fama_macbeth_regression(
    factor_values: dict[str, dict[str, pd.Series]],
    returns: dict[str, pd.Series],
) -> dict:
    """Fama-MacBeth two-pass cross-sectional regression.

    Pass 1: For each date, regress returns on all factor values (cross-sectional).
    Pass 2: Time-series average of each coefficient, t-stat = mean / (std / sqrt(T)).

    Parameters
    ----------
    factor_values : {factor_name: {symbol: factor_series}}
    returns : {symbol: return_series}

    Returns
    -------
    dict with keys: factor_premiums, t_statistics, r_squared_mean, observation_days,
                    significant_factors
    """
    factor_names = list(factor_values.keys())
    if not factor_names:
        return {"factor_premiums": {}, "t_statistics": {}, "r_squared_mean": 0.0,
                "observation_days": 0, "significant_factors": []}

    # Build DataFrames: rows = dates, cols = symbols
    ret_df = pd.DataFrame(returns)
    factor_dfs: dict[str, pd.DataFrame] = {
        fn: pd.DataFrame(fv) for fn, fv in factor_values.items()
    }

    common_dates = ret_df.index
    for fdf in factor_dfs.values():
        common_dates = common_dates.intersection(fdf.index)
    common_dates = common_dates.sort_values()

    if len(common_dates) == 0:
        return {"factor_premiums": {}, "t_statistics": {}, "r_squared_mean": 0.0,
                "observation_days": 0, "significant_factors": []}

    ret_df = ret_df.loc[common_dates]
    for fn in factor_names:
        factor_dfs[fn] = factor_dfs[fn].loc[common_dates]

    # Pass 1: cross-sectional regression per date
    betas_list: list[np.ndarray] = []
    r_squared_list: list[float] = []

    for date in common_dates:
        ret_row = ret_df.loc[date].dropna()
        syms = ret_row.index

        # Build factor matrix X
        X_parts = []
        valid = True
        for fn in factor_names:
            frow = factor_dfs[fn].loc[date].reindex(syms).dropna()
            common_syms = syms.intersection(frow.index)
            if len(common_syms) < len(factor_names) + 2:
                valid = False
                break
            syms = common_syms
            X_parts.append(frow.reindex(syms).values)

        if not valid or len(syms) < len(factor_names) + 2:
            continue

        y = ret_row.reindex(syms).values.astype(float)
        X = np.column_stack(X_parts).astype(float)

        # Add intercept
        X_with_intercept = np.column_stack([np.ones(len(syms)), X])

        try:
            betas, residuals, _, _ = np.linalg.lstsq(X_with_intercept, y, rcond=None)
            # betas[0] = intercept, betas[1:] = factor coefficients
            betas_list.append(betas[1:])

            # R-squared
            y_pred = X_with_intercept @ betas
            ss_res = np.sum((y - y_pred) ** 2)
            ss_tot = np.sum((y - np.mean(y)) ** 2)
            r2 = 1.0 - ss_res / ss_tot if ss_tot > 0 else 0.0
            r_squared_list.append(r2)
        except np.linalg.LinAlgError:
            continue

    if not betas_list:
        return {"factor_premiums": {}, "t_statistics": {}, "r_squared_mean": 0.0,
                "observation_days": 0, "significant_factors": []}

    # Pass 2: time-series average of betas
    betas_arr = np.array(betas_list)  # (T, n_factors)
    T = betas_arr.shape[0]

    factor_premiums: dict[str, float] = {}
    t_statistics: dict[str, float] = {}
    significant_factors: list[str] = []

    for j, fn in enumerate(factor_names):
        beta_ts = betas_arr[:, j]
        mean_beta = float(np.mean(beta_ts))
        std_beta = float(np.std(beta_ts, ddof=1)) if T > 1 else 0.0
        t_stat = mean_beta / (std_beta / math.sqrt(T)) if std_beta > 0 else 0.0

        factor_premiums[fn] = round(mean_beta, 6)
        t_statistics[fn] = round(t_stat, 4)
        if abs(t_stat) > 2.0:
            significant_factors.append(fn)

    return {
        "factor_premiums": factor_premiums,
        "t_statistics": t_statistics,
        "r_squared_mean": round(float(np.mean(r_squared_list)), 4),
        "observation_days": T,
        "significant_factors": significant_factors,
    }


def orthogonalize_factors(
    factor_values: dict[str, dict[str, pd.Series]],
    method: str = "gram_schmidt",
) -> dict[str, dict[str, pd.Series]]:
    """Orthogonalize factors using Gram-Schmidt sequential orthogonalization.

    Factor 1 stays as-is. Factor 2 is made orthogonal to factor 1.
    Factor 3 is made orthogonal to factors 1 and 2, etc.

    Parameters
    ----------
    factor_values : {factor_name: {symbol: factor_series}}
    method : only "gram_schmidt" supported

    Returns
    -------
    Orthogonalized factors in same structure.
    """
    if method != "gram_schmidt":
        raise ValueError(f"Unknown method: {method}")

    factor_names = list(factor_values.keys())
    if len(factor_names) <= 1:
        return {fn: {sym: s.copy() for sym, s in fv.items()}
                for fn, fv in factor_values.items()}

    # Build DataFrames per factor (rows=dates, cols=symbols)
    factor_dfs: dict[str, pd.DataFrame] = {
        fn: pd.DataFrame(fv) for fn, fv in factor_values.items()
    }

    # Find common dates and symbols
    common_dates = factor_dfs[factor_names[0]].index
    for fdf in factor_dfs.values():
        common_dates = common_dates.intersection(fdf.index)
    common_dates = common_dates.sort_values()

    common_symbols = set(factor_dfs[factor_names[0]].columns)
    for fdf in factor_dfs.values():
        common_symbols &= set(fdf.columns)
    common_symbols = sorted(common_symbols)

    if len(common_dates) == 0 or len(common_symbols) == 0:
        return {fn: {sym: s.copy() for sym, s in fv.items()}
                for fn, fv in factor_values.items()}

    # Align all DataFrames
    for fn in factor_names:
        factor_dfs[fn] = factor_dfs[fn].loc[common_dates, common_symbols].astype(float)

    # Gram-Schmidt: orthogonalize per date cross-sectionally
    result_dfs: dict[str, pd.DataFrame] = {}
    result_dfs[factor_names[0]] = factor_dfs[factor_names[0]].copy()

    for i in range(1, len(factor_names)):
        fn = factor_names[i]
        current = factor_dfs[fn].copy()

        for j in range(i):
            prev_fn = factor_names[j]
            prev = result_dfs[prev_fn]

            # Per-date: subtract projection of current onto previous
            for date in common_dates:
                v = current.loc[date].values.astype(float)
                u = prev.loc[date].values.astype(float)
                u_var = np.dot(u, u)
                if u_var > 0:
                    proj_coeff = np.dot(v, u) / u_var
                    current.loc[date] = v - proj_coeff * u

        result_dfs[fn] = current

    # Convert back to {factor: {symbol: series}}
    result: dict[str, dict[str, pd.Series]] = {}
    for fn in factor_names:
        df = result_dfs[fn]
        result[fn] = {col: df[col] for col in df.columns}

    return result


def out_of_sample_test(
    factor_values: dict[str, pd.Series],
    returns: dict[str, pd.Series],
    train_ratio: float = 0.7,
) -> dict:
    """Out-of-sample factor testing.

    Splits dates into train/test, computes IC on each set.

    Parameters
    ----------
    factor_values : {symbol: factor_series}
    returns : {symbol: return_series}
    train_ratio : fraction of dates used for training

    Returns
    -------
    dict with train_ic_mean, test_ic_mean, ic_decay, is_robust
    """
    # Get common dates
    all_dates = None
    for sym in factor_values:
        if all_dates is None:
            all_dates = set(factor_values[sym].index)
        else:
            all_dates &= set(factor_values[sym].index)
    for sym in returns:
        all_dates &= set(returns[sym].index)

    if not all_dates or len(all_dates) < 20:
        return {"train_ic_mean": 0.0, "test_ic_mean": 0.0,
                "ic_decay": 0.0, "is_robust": False}

    sorted_dates = sorted(all_dates)
    split_idx = int(len(sorted_dates) * train_ratio)
    if split_idx < 10 or split_idx >= len(sorted_dates):
        return {"train_ic_mean": 0.0, "test_ic_mean": 0.0,
                "ic_decay": 0.0, "is_robust": False}

    train_dates = set(sorted_dates[:split_idx])
    test_dates = set(sorted_dates[split_idx:])

    # Subset series to train/test dates
    def _subset(data: dict[str, pd.Series], dates: set) -> dict[str, pd.Series]:
        result = {}
        for sym, s in data.items():
            sub = s.loc[s.index.isin(dates)]
            if len(sub) > 0:
                result[sym] = sub
        return result

    fv_train = _subset(factor_values, train_dates)
    ret_train = _subset(returns, train_dates)
    fv_test = _subset(factor_values, test_dates)
    ret_test = _subset(returns, test_dates)

    ic_train = cross_sectional_ic(fv_train, ret_train)
    ic_test = cross_sectional_ic(fv_test, ret_test)

    train_ic_mean = float(ic_train.mean()) if len(ic_train) > 0 else 0.0
    test_ic_mean = float(ic_test.mean()) if len(ic_test) > 0 else 0.0

    # Decay: relative drop from train to test
    ic_decay = 0.0
    if abs(train_ic_mean) > 1e-6:
        ic_decay = 1.0 - abs(test_ic_mean) / abs(train_ic_mean)
    ic_decay = max(0.0, min(ic_decay, 1.0))  # clamp to [0, 1]

    is_robust = abs(test_ic_mean) > 0.02 and ic_decay < 0.5

    return {
        "train_ic_mean": round(train_ic_mean, 6),
        "test_ic_mean": round(test_ic_mean, 6),
        "ic_decay": round(ic_decay, 4),
        "is_robust": is_robust,
    }


def factor_decay_analysis(
    factor_values: dict[str, pd.Series],
    returns: dict[str, pd.Series],
    max_horizon: int = 30,
) -> dict:
    """Analyze how factor IC decays over different return horizons.

    Tests IC at horizons [1, 2, 3, 5, 10, 20, 30] days (capped by max_horizon).

    Parameters
    ----------
    factor_values : {symbol: factor_series}
    returns : {symbol: return_series} (used as base for computing forward returns)
    max_horizon : maximum horizon in days

    Returns
    -------
    dict mapping horizon -> {ic_mean, ic_std, significant}
    """
    # We need price data to compute multi-day returns.
    # Since we receive forward returns, we'll use the returns dict to infer
    # the underlying prices, or we'll treat factor_values + returns as the
    # base case and compute IC at the given horizon by re-indexing.
    #
    # Simpler approach: assume returns dict contains price series, and we
    # compute forward returns at each horizon. But the signature says returns.
    #
    # Practical approach: for each horizon h, shift the return series backward
    # by h-1 days to approximate h-day forward returns from daily returns.
    # Actually, since we don't have prices, we'll accumulate daily returns.

    horizons = [h for h in [1, 2, 3, 5, 10, 20, 30] if h <= max_horizon]
    if not horizons:
        return {}

    # Build return DataFrame
    ret_df = pd.DataFrame(returns)

    # For multi-day returns, we need the cumulative return.
    # The input `returns` are 1-day forward returns. For h-day, we need
    # cumulative of h consecutive daily returns.
    # Since we can't easily reconstruct prices from returns, we'll compute
    # h-day returns by summing consecutive 1-day returns (approximation).

    results: dict[int, dict] = {}

    for h in horizons:
        if h == 1:
            # Use returns as-is
            ic = cross_sectional_ic(factor_values, returns)
        else:
            # Create h-day cumulative returns by rolling sum
            multi_day_rets: dict[str, pd.Series] = {}
            for sym, ret_series in returns.items():
                # Rolling sum of h consecutive daily returns ≈ h-day return
                cum_ret = ret_series.rolling(h).sum()
                cum_ret = cum_ret.dropna()
                if len(cum_ret) > 0:
                    multi_day_rets[sym] = cum_ret
            ic = cross_sectional_ic(factor_values, multi_day_rets)

        if len(ic) > 0:
            ic_mean = float(ic.mean())
            ic_std = float(ic.std()) if len(ic) > 1 else 0.0
            # Significant if |t| > 2.0 (t = mean / (std / sqrt(n)))
            t_stat = abs(ic_mean) / (ic_std / math.sqrt(len(ic))) if ic_std > 0 else 0.0
            results[h] = {
                "ic_mean": round(ic_mean, 6),
                "ic_std": round(ic_std, 6),
                "significant": t_stat > 2.0,
            }
        else:
            results[h] = {"ic_mean": 0.0, "ic_std": 0.0, "significant": False}

    return results


def bonferroni_correction(p_values: list[float], alpha: float = 0.05) -> list[bool]:
    """Bonferroni correction for multiple testing.

    Adjusted alpha = alpha / n_tests. Each p-value is compared to the
    adjusted threshold.

    Parameters
    ----------
    p_values : list of raw p-values
    alpha : family-wise error rate (default 0.05)

    Returns
    -------
    list of booleans indicating which tests pass correction.
    """
    if not p_values:
        return []
    n = len(p_values)
    adjusted_alpha = alpha / n
    return [p <= adjusted_alpha for p in p_values]
