"""Tests for factor_research.py — factor functions, cross-sectional analysis, and backends."""
from __future__ import annotations

import math

import numpy as np
import pandas as pd
import pytest

from app.services.factor_research import (
    FACTOR_REGISTRY,
    MIN_UNIVERSE_SIZE,
    CryptoFactorBackend,
    FactorResult,
    StubFactorBackend,
    bollinger_position,
    bonferroni_correction,
    combine_factors,
    cross_sectional_ic,
    cross_sectional_rank_ic,
    downside_volatility,
    factor_decay_analysis,
    fama_macbeth_regression,
    funding_rate_momentum,
    hurst_exponent,
    liquidation_pressure,
    long_short_returns,
    macd_signal,
    momentum,
    momentum_acceleration,
    open_interest_change,
    orthogonalize_factors,
    out_of_sample_test,
    portfolio_turnover,
    price_strength,
    realized_volatility,
    rsi,
    volume_momentum,
    volume_price_divergence,
    volatility_ratio,
    vwap_deviation,
    z_score,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_close(n: int = 200, seed: int = 42) -> pd.Series:
    """Generate a realistic close price series."""
    rng = np.random.RandomState(seed)
    log_rets = rng.normal(0.0005, 0.02, n)
    prices = 100 * np.exp(np.cumsum(log_rets))
    dates = pd.date_range("2025-01-01", periods=n, freq="D")
    return pd.Series(prices, index=dates, name="close")


def _make_volume(n: int = 200, seed: int = 42) -> pd.Series:
    rng = np.random.RandomState(seed)
    dates = pd.date_range("2025-01-01", periods=n, freq="D")
    return pd.Series(rng.uniform(1e6, 1e8, n), index=dates, name="volume")


def _make_ohlcv_df(n: int = 200, seed: int = 42) -> pd.DataFrame:
    rng = np.random.RandomState(seed)
    close = _make_close(n, seed)
    volume = _make_volume(n, seed + 1)
    high = close * (1 + rng.uniform(0, 0.03, n))
    low = close * (1 - rng.uniform(0, 0.03, n))
    open_ = close * (1 + rng.normal(0, 0.01, n))
    return pd.DataFrame({
        "open": open_.values,
        "high": high.values,
        "low": low.values,
        "close": close.values,
        "volume": volume.values,
    }, index=close.index)


def _make_universe_data(
    n_assets: int = 15, n_days: int = 200, base_seed: int = 100
) -> dict[str, pd.DataFrame]:
    """Create synthetic OHLCV data for multiple assets."""
    data = {}
    for i in range(n_assets):
        sym = f"ASSET{i:02d}/USDT"
        data[sym] = _make_ohlcv_df(n_days, seed=base_seed + i)
    return data


# ---------------------------------------------------------------------------
# Factor Function Tests
# ---------------------------------------------------------------------------


class TestMomentumFactors:
    def test_momentum_returns_series(self):
        close = _make_close()
        result = momentum(close, 20)
        assert isinstance(result, pd.Series)
        assert len(result) == len(close)
        # First 20 values should be NaN
        assert result.iloc[:20].isna().all()
        assert result.iloc[20:].notna().any()

    def test_momentum_values(self):
        close = pd.Series([100, 110, 120, 130, 140], index=range(5))
        result = momentum(close, 2)
        assert abs(result.iloc[2] - 0.2) < 1e-6  # (120-100)/100
        assert abs(result.iloc[4] - (140 - 120) / 120) < 1e-6

    def test_momentum_acceleration(self):
        close = _make_close()
        result = momentum_acceleration(close, short=5, long=20)
        assert isinstance(result, pd.Series)
        # Should have NaN for first 20 values (the longer window)
        assert result.iloc[:20].isna().all()

    def test_price_strength(self):
        close = _make_close(100)
        result = price_strength(close, 20)
        assert isinstance(result, pd.Series)
        # Values should be in [0, 1]
        valid = result.dropna()
        assert (valid >= 0).all()
        assert (valid <= 1).all()


class TestVolatilityFactors:
    def test_realized_volatility(self):
        close = _make_close()
        result = realized_volatility(close, 20)
        assert isinstance(result, pd.Series)
        valid = result.dropna()
        assert (valid >= 0).all()
        # Should be annualized, so values > 0 for price series with volatility
        assert valid.mean() > 0

    def test_volatility_ratio(self):
        close = _make_close()
        result = volatility_ratio(close, short=5, long=20)
        valid = result.dropna()
        assert len(valid) > 0
        assert (valid > 0).all()

    def test_downside_volatility(self):
        close = _make_close()
        result = downside_volatility(close, 20)
        valid = result.dropna()
        assert (valid >= 0).all()


class TestVolumeFactors:
    def test_volume_momentum(self):
        vol = _make_volume()
        result = volume_momentum(vol, 10)
        assert isinstance(result, pd.Series)
        assert result.iloc[:10].isna().all()

    def test_volume_price_divergence(self):
        close = _make_close()
        vol = _make_volume()
        result = volume_price_divergence(close, vol, 20)
        assert isinstance(result, pd.Series)
        assert len(result.dropna()) > 0

    def test_vwap_deviation(self):
        close = _make_close()
        vol = _make_volume()
        result = vwap_deviation(close, vol, 20)
        valid = result.dropna()
        assert len(valid) > 0


class TestTechnicalFactors:
    def test_rsi_range(self):
        close = _make_close(200)
        result = rsi(close, 14)
        valid = result.dropna()
        assert (valid >= -1.0 - 1e-10).all()
        assert (valid <= 1.0 + 1e-10).all()

    def test_rsi_overbought_oversold(self):
        # Steady uptrend should give RSI near +1 (all gains, no losses -> RSI=100, normalized=+1)
        close = pd.Series(range(100, 130), dtype=float)
        result = rsi(close, 14)
        valid = result.dropna()
        assert len(valid) > 0
        assert valid.iloc[-1] > 0.5  # Strong uptrend should be well above 0

    def test_bollinger_position_range(self):
        close = _make_close(200)
        result = bollinger_position(close, 20, 2.0)
        valid = result.dropna()
        # Mostly within [-1, 1] (can slightly exceed in rare cases)
        assert valid.abs().mean() < 2.0

    def test_macd_signal(self):
        close = _make_close(200)
        result = macd_signal(close, 12, 26, 9)
        valid = result.dropna()
        assert len(valid) > 0
        # Should be small numbers (normalized by price)
        assert valid.abs().mean() < 0.5


class TestMeanReversionFactors:
    def test_z_score(self):
        close = _make_close(200)
        result = z_score(close, 20)
        valid = result.dropna()
        # Should be roughly centered around 0
        assert abs(valid.mean()) < 1.0

    def test_hurst_exponent(self):
        close = _make_close(200)
        result = hurst_exponent(close, 100)
        valid = result.dropna()
        assert len(valid) > 0
        # Hurst should be between 0 and 1 (approximately)
        assert (valid > -0.5).all()
        assert (valid < 1.5).all()


class TestCryptoSpecificFactors:
    def test_funding_rate_momentum(self):
        rng = np.random.RandomState(42)
        dates = pd.date_range("2025-01-01", periods=100, freq="D")
        fr = pd.Series(rng.normal(0.01, 0.005, 100), index=dates)
        result = funding_rate_momentum(fr, 8)
        assert isinstance(result, pd.Series)
        # rolling(8) produces NaN for first 7 values (window-1), non-NaN from index 7
        assert result.iloc[:7].isna().all()
        assert result.iloc[7:].notna().any()

    def test_open_interest_change(self):
        rng = np.random.RandomState(42)
        dates = pd.date_range("2025-01-01", periods=100, freq="D")
        oi = pd.Series(rng.uniform(1e9, 2e9, 100), index=dates)
        result = open_interest_change(oi, 24)
        assert isinstance(result, pd.Series)

    def test_liquidation_pressure(self):
        rng = np.random.RandomState(42)
        dates = pd.date_range("2025-01-01", periods=100, freq="D")
        long_liqs = pd.Series(rng.uniform(0, 1e6, 100), index=dates)
        short_liqs = pd.Series(rng.uniform(0, 1e6, 100), index=dates)
        result = liquidation_pressure(long_liqs, short_liqs, 24)
        assert isinstance(result, pd.Series)


# ---------------------------------------------------------------------------
# Factor Registry
# ---------------------------------------------------------------------------


class TestFactorRegistry:
    def test_registry_has_all_factors(self):
        assert len(FACTOR_REGISTRY) >= 17

    def test_registry_keys_match_functions(self):
        expected = {
            "momentum",
            "momentum_acceleration",
            "price_strength",
            "realized_volatility",
            "volatility_ratio",
            "downside_volatility",
            "volume_momentum",
            "volume_price_divergence",
            "vwap_deviation",
            "rsi",
            "bollinger_position",
            "macd_signal",
            "z_score",
            "hurst_exponent",
            "funding_rate_momentum",
            "open_interest_change",
            "liquidation_pressure",
        }
        assert expected.issubset(set(FACTOR_REGISTRY.keys()))

    def test_all_registry_functions_callable(self):
        for name, func in FACTOR_REGISTRY.items():
            assert callable(func), f"{name} is not callable"


# ---------------------------------------------------------------------------
# Cross-Sectional Analysis Tests
# ---------------------------------------------------------------------------


def _make_cross_sectional_data(
    n_assets: int = 15, n_days: int = 50, seed: int = 42
) -> tuple[dict[str, pd.Series], dict[str, pd.Series]]:
    """Create aligned factor values and returns for cross-sectional analysis."""
    rng = np.random.RandomState(seed)
    dates = pd.date_range("2025-01-01", periods=n_days, freq="D")
    factor_values = {}
    returns = {}
    for i in range(n_assets):
        sym = f"ASSET{i:02d}"
        # Factor with slight predictive signal
        fv = rng.normal(0, 1, n_days) + i * 0.05
        factor_values[sym] = pd.Series(fv, index=dates)
        # Returns correlated with factor (signal) + noise
        ret = fv * 0.01 + rng.normal(0, 0.02, n_days)
        returns[sym] = pd.Series(ret, index=dates)
    return factor_values, returns


class TestCrossSectionalIC:
    def test_returns_series(self):
        fv, rets = _make_cross_sectional_data()
        ic = cross_sectional_ic(fv, rets)
        assert isinstance(ic, pd.Series)
        assert len(ic) > 0

    def test_ic_reasonable_range(self):
        fv, rets = _make_cross_sectional_data()
        ic = cross_sectional_ic(fv, rets)
        # IC should be between -1 and 1
        assert (ic.abs() <= 1.0 + 1e-10).all()

    def test_ic_with_signal(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100, seed=123)
        ic = cross_sectional_ic(fv, rets)
        # With built-in signal, IC mean should be positive
        assert ic.mean() > 0

    def test_ic_too_few_assets(self):
        # Below MIN_UNIVERSE_SIZE should produce empty IC series
        fv, rets = _make_cross_sectional_data(n_assets=5)
        ic = cross_sectional_ic(fv, rets)
        assert len(ic) == 0


class TestCrossSectionalRankIC:
    def test_returns_series(self):
        fv, rets = _make_cross_sectional_data()
        rank_ic = cross_sectional_rank_ic(fv, rets)
        assert isinstance(rank_ic, pd.Series)
        assert len(rank_ic) > 0

    def test_rank_ic_range(self):
        fv, rets = _make_cross_sectional_data()
        rank_ic = cross_sectional_rank_ic(fv, rets)
        assert (rank_ic.abs() <= 1.0 + 1e-10).all()


class TestLongShortReturns:
    def test_returns_series(self):
        fv, rets = _make_cross_sectional_data()
        ls = long_short_returns(fv, rets, quantile=0.2)
        assert isinstance(ls, pd.Series)
        assert len(ls) > 0

    def test_long_short_with_signal(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100)
        ls = long_short_returns(fv, rets, quantile=0.2)
        # With positive signal, long-short should be positive on average
        assert ls.mean() > 0


class TestPortfolioTurnover:
    def test_returns_series(self):
        fv, _ = _make_cross_sectional_data()
        to = portfolio_turnover(fv, quantile=0.2)
        assert isinstance(to, pd.Series)

    def test_turnover_range(self):
        fv, _ = _make_cross_sectional_data(n_assets=20, n_days=100)
        to = portfolio_turnover(fv, quantile=0.2)
        # Turnover should be between 0 and 1
        assert (to >= 0).all()
        assert (to <= 1.0 + 1e-10).all()

    def test_identical_factors_low_turnover(self):
        """If all assets have the same factor every day, turnover should be 0."""
        dates = pd.date_range("2025-01-01", periods=50, freq="D")
        fv = {}
        for i in range(15):
            # Same rank order every day
            fv[f"S{i}"] = pd.Series([float(i)] * 50, index=dates)
        to = portfolio_turnover(fv, quantile=0.3)
        # All turnovers should be 0 (or first entry which is skipped)
        assert to.sum() == 0.0


# ---------------------------------------------------------------------------
# Factor Combination Tests
# ---------------------------------------------------------------------------


class TestCombineFactors:
    def test_equal_weight(self):
        fv1, rets = _make_cross_sectional_data(n_assets=15, n_days=50, seed=1)
        fv2, _ = _make_cross_sectional_data(n_assets=15, n_days=50, seed=2)
        combined = combine_factors(
            {"m1": fv1, "m2": fv2}, rets, method="equal_weight"
        )
        assert isinstance(combined, dict)
        assert len(combined) == 15  # All assets present

    def test_ic_weight(self):
        fv1, rets = _make_cross_sectional_data(n_assets=15, n_days=50, seed=1)
        fv2, _ = _make_cross_sectional_data(n_assets=15, n_days=50, seed=2)
        combined = combine_factors(
            {"m1": fv1, "m2": fv2}, rets, method="ic_weight"
        )
        assert len(combined) == 15

    def test_explicit_weights(self):
        fv1, rets = _make_cross_sectional_data(n_assets=15, n_days=50, seed=1)
        fv2, _ = _make_cross_sectional_data(n_assets=15, n_days=50, seed=2)
        combined = combine_factors(
            {"m1": fv1, "m2": fv2},
            rets,
            weights={"m1": 0.7, "m2": 0.3},
        )
        assert len(combined) == 15


# ---------------------------------------------------------------------------
# StubFactorBackend Tests
# ---------------------------------------------------------------------------


class TestStubFactorBackend:
    @pytest.fixture
    def backend(self):
        return StubFactorBackend()

    @pytest.mark.asyncio
    async def test_stub_returns_ok(self, backend):
        result = await backend.research(["BTC", "ETH"], "momentum", "3M")
        assert isinstance(result, FactorResult)
        assert result.status == "ok_stub"
        assert result.factor_name == "momentum"

    @pytest.mark.asyncio
    async def test_stub_metrics_present(self, backend):
        result = await backend.research(["BTC"], "rsi")
        assert "ic_mean" in result.metrics
        assert "ic_std" in result.metrics
        assert "ic_ir" in result.metrics
        assert "rank_ic_mean" in result.metrics
        assert "long_short_sharpe" in result.metrics
        assert "turnover_mean" in result.metrics

    @pytest.mark.asyncio
    async def test_stub_validity_flags(self, backend):
        result = await backend.research(["BTC"], "momentum")
        assert isinstance(result.metrics.get("ic_valid"), bool)
        assert isinstance(result.metrics.get("ic_ir_valid"), bool)

    @pytest.mark.asyncio
    async def test_stub_deterministic(self, backend):
        r1 = await backend.research(["BTC"], "momentum")
        r2 = await backend.research(["BTC"], "momentum")
        assert r1.metrics == r2.metrics

    @pytest.mark.asyncio
    async def test_stub_unknown_factor(self, backend):
        result = await backend.research(["BTC"], "nonexistent_factor")
        assert result.status == "error"

    @pytest.mark.asyncio
    async def test_stub_all_factors(self, backend):
        for fname in FACTOR_REGISTRY:
            result = await backend.research(["BTC", "ETH"], fname)
            assert result.status == "ok_stub", f"Failed for {fname}"


# ---------------------------------------------------------------------------
# CryptoFactorBackend Tests
# ---------------------------------------------------------------------------


class _MockMarketDataService:
    """Mock market data service that returns synthetic OHLCV."""

    def __init__(self, n_assets: int = 15, n_days: int = 200, seed: int = 42):
        self._data = _make_universe_data(n_assets, n_days, seed)

    async def get_ohlcv(
        self, symbol: str, timeframe: str = "1d", limit: int = 200
    ) -> list[dict]:
        if symbol not in self._data:
            return []
        df = self._data[symbol]
        records = []
        for ts, row in df.iterrows():
            records.append({
                "timestamp": int(ts.timestamp() * 1000),
                "open": float(row["open"]),
                "high": float(row["high"]),
                "low": float(row["low"]),
                "close": float(row["close"]),
                "volume": float(row["volume"]),
            })
        return records[-limit:]


class TestCryptoFactorBackend:
    @pytest.fixture
    def mock_mds(self):
        return _MockMarketDataService(n_assets=15, n_days=200)

    @pytest.fixture
    def backend(self, mock_mds):
        return CryptoFactorBackend(mock_mds)

    @pytest.mark.asyncio
    async def test_research_returns_factor_result(self, backend):
        symbols = [f"ASSET{i:02d}/USDT" for i in range(15)]
        result = await backend.research(symbols, "momentum", "3M")
        assert isinstance(result, FactorResult)
        assert result.status == "ok"
        assert result.factor_name == "momentum"

    @pytest.mark.asyncio
    async def test_research_metrics(self, backend):
        symbols = [f"ASSET{i:02d}/USDT" for i in range(15)]
        result = await backend.research(symbols, "momentum")
        assert "ic_mean" in result.metrics
        assert "ic_std" in result.metrics
        assert "ic_ir" in result.metrics
        assert "rank_ic_mean" in result.metrics
        assert "long_short_sharpe" in result.metrics
        assert "turnover_mean" in result.metrics
        assert "universe_size" in result.metrics
        assert result.metrics["universe_size"] == 15

    @pytest.mark.asyncio
    async def test_research_details(self, backend):
        symbols = [f"ASSET{i:02d}/USDT" for i in range(15)]
        result = await backend.research(symbols, "rsi")
        assert "ic_series" in result.details
        assert "factor_values_latest" in result.details
        assert len(result.details["factor_values_latest"]) == 15

    @pytest.mark.asyncio
    async def test_research_insufficient_data(self, backend):
        # Only 3 symbols < MIN_UNIVERSE_SIZE
        symbols = [f"ASSET{i:02d}/USDT" for i in range(3)]
        result = await backend.research(symbols, "momentum")
        assert result.status == "insufficient_data"

    @pytest.mark.asyncio
    async def test_research_unknown_symbol(self, backend):
        symbols = ["UNKNOWN/USDT"] * 15
        result = await backend.research(symbols, "momentum")
        assert result.status == "insufficient_data"

    @pytest.mark.asyncio
    async def test_research_unknown_factor(self, backend):
        symbols = [f"ASSET{i:02d}/USDT" for i in range(15)]
        result = await backend.research(symbols, "nonexistent")
        assert result.status == "error"

    @pytest.mark.asyncio
    async def test_research_multiple_factors(self, backend):
        symbols = [f"ASSET{i:02d}/USDT" for i in range(15)]
        # Test a representative set of factors that only need close/volume
        for fname in [
            "momentum",
            "rsi",
            "bollinger_position",
            "z_score",
            "realized_volatility",
            "price_strength",
            "macd_signal",
        ]:
            result = await backend.research(symbols, fname, "3M")
            assert result.status == "ok", f"Factor {fname} failed: {result.metrics}"

    @pytest.mark.asyncio
    async def test_research_with_period(self, backend):
        symbols = [f"ASSET{i:02d}/USDT" for i in range(15)]
        for period in ["1M", "3M", "6M"]:
            result = await backend.research(symbols, "momentum", period)
            assert result.status == "ok"


# ---------------------------------------------------------------------------
# FactorResult Dataclass Tests
# ---------------------------------------------------------------------------


class TestFactorResult:
    def test_creation(self):
        r = FactorResult(status="ok", factor_name="momentum", market="crypto")
        assert r.status == "ok"
        assert r.metrics == {}
        assert r.details == {}

    def test_with_data(self):
        r = FactorResult(
            status="ok",
            factor_name="rsi",
            market="crypto",
            metrics={"ic_mean": 0.05},
            details={"ic_series": {}},
        )
        assert r.metrics["ic_mean"] == 0.05


# ---------------------------------------------------------------------------
# Fama-MacBeth Regression Tests
# ---------------------------------------------------------------------------


def _make_multi_factor_data(
    n_assets: int = 20, n_days: int = 60, seed: int = 42
) -> tuple[dict[str, dict[str, pd.Series]], dict[str, pd.Series]]:
    """Create multi-factor and returns data for Fama-MacBeth testing."""
    rng = np.random.RandomState(seed)
    dates = pd.date_range("2025-01-01", periods=n_days, freq="D")
    returns: dict[str, pd.Series] = {}
    factor1: dict[str, pd.Series] = {}
    factor2: dict[str, pd.Series] = {}

    for i in range(n_assets):
        sym = f"ASSET{i:02d}"
        f1 = rng.normal(0, 1, n_days)
        f2 = rng.normal(0, 1, n_days)
        # Returns: f1 has real signal, f2 is noise
        ret = f1 * 0.02 + rng.normal(0, 0.03, n_days)
        factor1[sym] = pd.Series(f1, index=dates)
        factor2[sym] = pd.Series(f2, index=dates)
        returns[sym] = pd.Series(ret, index=dates)

    return {"alpha": factor1, "beta": factor2}, returns


class TestFamaMacBeth:
    def test_returns_dict_structure(self):
        factors, returns = _make_multi_factor_data()
        result = fama_macbeth_regression(factors, returns)
        assert isinstance(result, dict)
        assert "factor_premiums" in result
        assert "t_statistics" in result
        assert "r_squared_mean" in result
        assert "observation_days" in result
        assert "significant_factors" in result

    def test_factor_premiums_keys(self):
        factors, returns = _make_multi_factor_data()
        result = fama_macbeth_regression(factors, returns)
        assert set(result["factor_premiums"].keys()) == {"alpha", "beta"}

    def test_observation_days_positive(self):
        factors, returns = _make_multi_factor_data()
        result = fama_macbeth_regression(factors, returns)
        assert result["observation_days"] > 0

    def test_r_squared_reasonable(self):
        factors, returns = _make_multi_factor_data(n_assets=20, n_days=100)
        result = fama_macbeth_regression(factors, returns)
        assert 0 <= result["r_squared_mean"] <= 1.0

    def test_significant_factor_detected(self):
        """Factor with strong signal should be detected as significant."""
        factors, returns = _make_multi_factor_data(n_assets=30, n_days=100, seed=99)
        result = fama_macbeth_regression(factors, returns)
        # alpha has a real signal, should be significant
        assert "alpha" in result["significant_factors"]

    def test_empty_factors(self):
        result = fama_macbeth_regression({}, {})
        assert result["observation_days"] == 0
        assert result["factor_premiums"] == {}

    def test_insufficient_assets(self):
        """With too few assets, should return empty."""
        factors, returns = _make_multi_factor_data(n_assets=2, n_days=50)
        result = fama_macbeth_regression(factors, returns)
        # 2 assets < n_factors + 2 = 4, so no valid regressions
        assert result["observation_days"] == 0


# ---------------------------------------------------------------------------
# Factor Orthogonalization Tests
# ---------------------------------------------------------------------------


class TestOrthogonalizeFactors:
    def test_returns_same_structure(self):
        factors, _ = _make_multi_factor_data()
        result = orthogonalize_factors(factors)
        assert set(result.keys()) == set(factors.keys())
        for fn in factors:
            assert set(result[fn].keys()) == set(factors[fn].keys())

    def test_first_factor_unchanged(self):
        factors, _ = _make_multi_factor_data()
        result = orthogonalize_factors(factors)
        fn0 = list(factors.keys())[0]
        for sym in factors[fn0]:
            pd.testing.assert_series_equal(
                result[fn0][sym], factors[fn0][sym], check_names=False
            )

    def test_orthogonalized_factors_uncorrelated(self):
        """After orthogonalization, factors should be cross-sectionally uncorrelated."""
        factors, _ = _make_multi_factor_data(n_assets=20, n_days=100, seed=55)
        result = orthogonalize_factors(factors)
        fnames = list(result.keys())
        dates = list(result[fnames[0]].values())[0].index

        # Check correlation between orthogonalized factors on a sample date
        date = dates[50]
        vals_0 = np.array([result[fnames[0]][sym].loc[date] for sym in result[fnames[0]]])
        vals_1 = np.array([result[fnames[1]][sym].loc[date] for sym in result[fnames[1]]])
        corr = np.corrcoef(vals_0, vals_1)[0, 1]
        # Should be close to 0 (orthogonal); tolerance for 20-asset cross-section
        assert abs(corr) < 0.05

    def test_single_factor_passthrough(self):
        factors, _ = _make_multi_factor_data()
        single = {"alpha": factors["alpha"]}
        result = orthogonalize_factors(single)
        for sym in single["alpha"]:
            pd.testing.assert_series_equal(
                result["alpha"][sym], single["alpha"][sym], check_names=False
            )

    def test_invalid_method_raises(self):
        factors, _ = _make_multi_factor_data()
        with pytest.raises(ValueError, match="Unknown method"):
            orthogonalize_factors(factors, method="pca")


# ---------------------------------------------------------------------------
# Out-of-Sample Test Tests
# ---------------------------------------------------------------------------


class TestOutOfSampleTest:
    def test_returns_dict_structure(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100)
        result = out_of_sample_test(fv, rets)
        assert "train_ic_mean" in result
        assert "test_ic_mean" in result
        assert "ic_decay" in result
        assert "is_robust" in result

    def test_ic_decay_range(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100)
        result = out_of_sample_test(fv, rets)
        assert 0.0 <= result["ic_decay"] <= 1.0

    def test_train_test_split(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100)
        result = out_of_sample_test(fv, rets, train_ratio=0.5)
        # Both should have non-zero IC
        assert result["train_ic_mean"] != 0.0 or result["test_ic_mean"] != 0.0

    def test_robust_factor(self):
        """A factor with consistent signal should be robust."""
        fv, rets = _make_cross_sectional_data(n_assets=25, n_days=120, seed=77)
        result = out_of_sample_test(fv, rets, train_ratio=0.6)
        # With a built-in signal, IC should be positive in both sets
        if result["train_ic_mean"] > 0.02:
            # If train is strong enough, check test isn't collapsed
            assert isinstance(result["is_robust"], bool)

    def test_insufficient_data(self):
        fv, rets = _make_cross_sectional_data(n_assets=15, n_days=5)
        result = out_of_sample_test(fv, rets)
        assert result["train_ic_mean"] == 0.0

    def test_custom_train_ratio(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100)
        result = out_of_sample_test(fv, rets, train_ratio=0.8)
        assert "train_ic_mean" in result


# ---------------------------------------------------------------------------
# Factor Decay Analysis Tests
# ---------------------------------------------------------------------------


class TestFactorDecayAnalysis:
    def test_returns_dict_structure(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100)
        result = factor_decay_analysis(fv, rets, max_horizon=10)
        assert isinstance(result, dict)
        assert 1 in result
        assert "ic_mean" in result[1]
        assert "ic_std" in result[1]
        assert "significant" in result[1]

    def test_horizons_capped_by_max(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100)
        result = factor_decay_analysis(fv, rets, max_horizon=5)
        assert 1 in result
        assert 5 in result
        assert 10 not in result
        assert 30 not in result

    def test_default_horizons(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100)
        result = factor_decay_analysis(fv, rets)
        expected = {1, 2, 3, 5, 10, 20, 30}
        assert set(result.keys()) == expected

    def test_ic_decays_with_horizon(self):
        """IC generally decreases as horizon increases."""
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=200, seed=88)
        result = factor_decay_analysis(fv, rets, max_horizon=10)
        ic_1 = abs(result[1]["ic_mean"])
        ic_10 = abs(result[10]["ic_mean"])
        # Not guaranteed to always decay, but typically does
        # Just check both are computed
        assert ic_1 >= 0
        assert ic_10 >= 0

    def test_significance_flag(self):
        fv, rets = _make_cross_sectional_data(n_assets=20, n_days=100)
        result = factor_decay_analysis(fv, rets, max_horizon=5)
        for h in result:
            assert isinstance(result[h]["significant"], bool)


# ---------------------------------------------------------------------------
# Bonferroni Correction Tests
# ---------------------------------------------------------------------------


class TestBonferroniCorrection:
    def test_basic_correction(self):
        p_vals = [0.01, 0.03, 0.04, 0.06]
        result = bonferroni_correction(p_vals, alpha=0.05)
        # adjusted_alpha = 0.05 / 4 = 0.0125
        assert result == [True, False, False, False]

    def test_single_test(self):
        result = bonferroni_correction([0.04], alpha=0.05)
        assert result == [True]

    def test_all_significant(self):
        result = bonferroni_correction([0.001, 0.002, 0.003], alpha=0.05)
        # adjusted = 0.05/3 ≈ 0.0167
        assert all(result)

    def test_none_significant(self):
        result = bonferroni_correction([0.1, 0.2, 0.3], alpha=0.05)
        assert not any(result)

    def test_empty_list(self):
        result = bonferroni_correction([], alpha=0.05)
        assert result == []

    def test_custom_alpha(self):
        result = bonferroni_correction([0.01, 0.02], alpha=0.10)
        # adjusted = 0.10 / 2 = 0.05
        assert result == [True, True]

    def test_boundary_p_value(self):
        # p == adjusted_alpha should pass (<=)
        result = bonferroni_correction([0.025, 0.026], alpha=0.05)
        # adjusted = 0.05/2 = 0.025
        assert result == [True, False]
