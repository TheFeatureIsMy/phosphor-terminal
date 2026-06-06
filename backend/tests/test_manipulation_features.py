"""Tests for manipulation OHLCV feature computation."""
from app.services.manipulation.features import (
    compute_all_features,
    wick_ratio_up,
    wick_ratio_down,
    volume_zscore,
    price_range_spike,
    pump_then_dump,
    dump_then_recover,
    pinbar_score,
    volume_price_divergence,
)


def _flat_candles(n: int = 30, price: float = 100.0, volume: float = 10000.0) -> list[dict]:
    return [
        {"open": price, "high": price * 1.001, "low": price * 0.999, "close": price, "volume": volume}
        for _ in range(n)
    ]


def _spike_up_candles(n: int = 30) -> list[dict]:
    candles = _flat_candles(n - 5)
    for _ in range(5):
        candles.append({"open": 100, "high": 120, "low": 99, "close": 101, "volume": 10000})
    return candles


def _pinbar_candles(n: int = 30) -> list[dict]:
    candles = _flat_candles(n - 5)
    for _ in range(5):
        candles.append({"open": 100, "high": 110, "low": 95, "close": 100.5, "volume": 10000})
    return candles


class TestWickRatio:
    def test_flat_market_low_score(self):
        assert wick_ratio_up(_flat_candles()) < 20

    def test_spike_up_high_score(self):
        assert wick_ratio_up(_spike_up_candles()) > 50

    def test_insufficient_data(self):
        assert wick_ratio_up([{"open": 1, "high": 2, "low": 0, "close": 1, "volume": 1}]) == 0.0


class TestVolumeZscore:
    def test_uniform_volume_low_score(self):
        assert volume_zscore(_flat_candles()) < 20

    def test_volume_spike_high_score(self):
        candles = [
            {"open": 100, "high": 101, "low": 99, "close": 100, "volume": 10000 + i * 100}
            for i in range(25)
        ]
        candles.append({"open": 100, "high": 101, "low": 99, "close": 100, "volume": 100000})
        assert volume_zscore(candles) > 50

    def test_insufficient_data(self):
        assert volume_zscore(_flat_candles(5)) == 0.0


class TestPumpThenDump:
    def test_flat_market_zero(self):
        assert pump_then_dump(_flat_candles()) < 5

    def test_pump_dump_pattern(self):
        candles = _flat_candles(20)
        for _ in range(5):
            candles.append({"open": 100, "high": 108, "low": 99, "close": 107, "volume": 10000})
        for _ in range(5):
            candles.append({"open": 107, "high": 108, "low": 100, "close": 101, "volume": 10000})
        assert pump_then_dump(candles) > 40


class TestPinbar:
    def test_normal_candles_low(self):
        assert pinbar_score(_flat_candles()) < 20

    def test_pinbar_candles_high(self):
        assert pinbar_score(_pinbar_candles()) > 30


class TestVolumePriceDivergence:
    def test_no_divergence(self):
        assert volume_price_divergence(_flat_candles()) < 10

    def test_volume_up_price_flat(self):
        candles = []
        for i in range(10):
            candles.append({
                "open": 100, "high": 100.5, "low": 99.5, "close": 100,
                "volume": 10000 * (1 + i * 0.5),
            })
        score = volume_price_divergence(candles)
        assert score > 10


class TestComputeAll:
    def test_returns_all_keys(self):
        features = compute_all_features(_flat_candles())
        expected_keys = {
            "wick_ratio_up", "wick_ratio_down", "volume_zscore",
            "price_range_spike", "pump_then_dump", "dump_then_recover",
            "pinbar_score", "volume_price_divergence",
        }
        assert set(features.keys()) == expected_keys

    def test_all_values_bounded(self):
        features = compute_all_features(_flat_candles())
        for k, v in features.items():
            assert 0 <= v <= 100, f"{k} = {v} out of bounds"
