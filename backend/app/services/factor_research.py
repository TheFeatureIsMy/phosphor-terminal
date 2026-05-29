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


class StubFactorBackend:
    """Deterministic fallback when market data is unavailable.

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
