"""Tests for dsl_interpreter.py — indicators, operators, rules, groups, filters."""
import os
import sys
import math

import numpy as np
import pandas as pd
import pytest

BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

from app.services.dsl_interpreter import (
    compute_indicator,
    apply_operator,
    evaluate_rule,
    evaluate_group,
    evaluate_filters,
    compute_all_indicators,
    _get_indicator,
)


# ── Helpers ─────────────────────────────────────────────────────────

def _make_df(n=100, seed=42):
    rng = np.random.RandomState(seed)
    close = 100 + np.cumsum(rng.randn(n) * 0.5)
    return pd.DataFrame({
        "open": close - rng.uniform(0, 1, n),
        "high": close + rng.uniform(0, 2, n),
        "low": close - rng.uniform(0, 2, n),
        "close": close,
        "volume": rng.uniform(1e6, 5e6, n),
    })


@pytest.fixture
def df():
    return _make_df(100)


@pytest.fixture
def short_df():
    return _make_df(10)


# ── Indicator tests ─────────────────────────────────────────────────

class TestComputeIndicator:
    def test_rsi_basic(self, df):
        s = compute_indicator(df, "rsi", {"period": 14})
        assert len(s) == len(df)
        valid = s.dropna()
        assert len(valid) > 0
        assert valid.min() >= 0
        assert valid.max() <= 100

    def test_ema_basic(self, df):
        s = compute_indicator(df, "ema", {"period": 20})
        valid = s.dropna()
        assert len(valid) > 0
        assert abs(valid.iloc[-1] - df["close"].iloc[-20:].mean()) < 10

    def test_sma_basic(self, df):
        s = compute_indicator(df, "sma", {"period": 20})
        expected = df["close"].iloc[-20:].mean()
        assert abs(s.iloc[-1] - expected) < 1e-10

    def test_macd_basic(self, df):
        s = compute_indicator(df, "macd", {"fast": 12, "slow": 26})
        assert len(s) == len(df)
        assert s.dropna().shape[0] > 0

    def test_macd_signal_basic(self, df):
        s = compute_indicator(df, "macd_signal", {"fast": 12, "slow": 26, "signal": 9})
        assert len(s) == len(df)

    def test_bb_upper(self, df):
        upper = compute_indicator(df, "bb_upper", {"period": 20, "std": 2})
        sma = compute_indicator(df, "sma", {"period": 20})
        valid_idx = upper.dropna().index
        assert (upper[valid_idx] >= sma[valid_idx]).all()

    def test_bb_lower(self, df):
        lower = compute_indicator(df, "bb_lower", {"period": 20, "std": 2})
        sma = compute_indicator(df, "sma", {"period": 20})
        valid_idx = lower.dropna().index
        assert (lower[valid_idx] <= sma[valid_idx]).all()

    def test_atr(self, df):
        s = compute_indicator(df, "atr", {"period": 14})
        valid = s.dropna()
        assert (valid >= 0).all()

    def test_volume(self, df):
        s = compute_indicator(df, "volume", {})
        pd.testing.assert_series_equal(s, df["volume"].astype(float), check_names=False)

    def test_volume_sma(self, df):
        s = compute_indicator(df, "volume_sma", {"period": 20})
        expected = df["volume"].astype(float).rolling(20, min_periods=20).mean()
        pd.testing.assert_series_equal(s, expected, check_names=False)

    def test_price_columns(self, df):
        for col in ("close", "open", "high", "low"):
            s = compute_indicator(df, col, {})
            pd.testing.assert_series_equal(s, df[col].astype(float), check_names=False)

    def test_unknown_indicator_returns_nan(self, df):
        s = compute_indicator(df, "does_not_exist", {})
        assert s.isna().all()

    def test_default_params(self, df):
        s = compute_indicator(df, "rsi", {})
        assert len(s) == len(df)


# ── Operator tests ──────────────────────────────────────────────────

class TestApplyOperator:
    def test_gt(self):
        s = pd.Series([1, 5, 10])
        result = apply_operator(s, ">", value=5)
        assert list(result) == [False, False, True]

    def test_gte(self):
        s = pd.Series([1, 5, 10])
        result = apply_operator(s, ">=", value=5)
        assert list(result) == [False, True, True]

    def test_lt(self):
        s = pd.Series([1, 5, 10])
        result = apply_operator(s, "<", value=5)
        assert list(result) == [True, False, False]

    def test_lte(self):
        s = pd.Series([1, 5, 10])
        result = apply_operator(s, "<=", value=5)
        assert list(result) == [True, True, False]

    def test_eq(self):
        s = pd.Series([1, 5, 10])
        result = apply_operator(s, "==", value=5)
        assert list(result) == [False, True, False]

    def test_neq(self):
        s = pd.Series([1, 5, 10])
        result = apply_operator(s, "!=", value=5)
        assert list(result) == [True, False, True]

    def test_between(self):
        s = pd.Series([1, 5, 10])
        result = apply_operator(s, "between", min_value=3, max_value=7)
        assert list(result) == [False, True, False]

    def test_not_between(self):
        s = pd.Series([1, 5, 10])
        result = apply_operator(s, "not_between", min_value=3, max_value=7)
        assert list(result) == [True, False, True]

    def test_crosses_above(self):
        s = pd.Series([1.0, 3.0, 5.0, 3.0])
        other = pd.Series([2.0, 4.0, 4.0, 4.0])
        result = apply_operator(s, "crosses_above", other_series=other)
        assert result.iloc[2] == True
        assert result.iloc[0] == False

    def test_crosses_below(self):
        s = pd.Series([5.0, 3.0, 1.0, 3.0])
        other = pd.Series([4.0, 4.0, 4.0, 2.0])
        result = apply_operator(s, "crosses_below", other_series=other)
        assert result.iloc[1] == True

    def test_unknown_operator_returns_false(self):
        s = pd.Series([1, 2, 3])
        result = apply_operator(s, "invalid_op", value=2)
        assert (result == False).all()


# ── Rule evaluation tests ──────────────────────────────────────────

class TestEvaluateRule:
    def test_indicator_threshold_lt(self, df):
        rule = {
            "type": "indicator_threshold",
            "indicator": "rsi",
            "params": {"period": 14},
            "operator": "<",
            "value": 30,
        }
        cache = {}
        result = evaluate_rule(df, rule, cache)
        assert result.dtype == bool
        assert len(result) == len(df)

    def test_indicator_threshold_between(self, df):
        rule = {
            "type": "indicator_threshold",
            "indicator": "rsi",
            "params": {"period": 14},
            "operator": "between",
            "min_value": 30,
            "max_value": 70,
        }
        cache = {}
        result = evaluate_rule(df, rule, cache)
        assert result.dtype == bool

    def test_indicator_cross(self, df):
        rule = {
            "type": "indicator_cross",
            "indicator": "ema",
            "params": {"period": 12},
            "cross_indicator": "ema",
            "cross_params": {"period": 26},
            "direction": "crosses_above",
        }
        cache = {}
        result = evaluate_rule(df, rule, cache)
        assert result.dtype == bool

    def test_volume_filter(self, df):
        median_vol = df["volume"].median()
        rule = {
            "type": "volume_filter",
            "indicator": "volume",
            "params": {},
            "operator": ">",
            "value": median_vol,
        }
        cache = {}
        result = evaluate_rule(df, rule, cache)
        assert result.sum() > 0
        assert result.sum() < len(df)

    def test_cooldown_filter_always_true(self, df):
        rule = {"type": "cooldown_filter", "candles": 5}
        result = evaluate_rule(df, rule, {})
        assert result.all()

    def test_signal_confirmation_always_true(self, df):
        rule = {"type": "signal_confirmation", "min_confidence": 0.8}
        result = evaluate_rule(df, rule, {})
        assert result.all()

    def test_unsupported_rule_type_returns_false(self, df):
        rule = {"type": "nonexistent_rule_type"}
        result = evaluate_rule(df, rule, {})
        assert (result == False).all()

    def test_indicator_cache_is_used(self, df):
        cache = {}
        rule = {
            "type": "indicator_threshold",
            "indicator": "rsi",
            "params": {"period": 14},
            "operator": "<",
            "value": 50,
        }
        evaluate_rule(df, rule, cache)
        assert len(cache) > 0
        key = list(cache.keys())[0]
        cached_series = cache[key].copy()
        evaluate_rule(df, rule, cache)
        pd.testing.assert_series_equal(cache[key], cached_series)


# ── Group evaluation tests ──────────────────────────────────────────

class TestEvaluateGroup:
    def test_and_logic(self, df):
        group = {
            "logic": "AND",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": "<", "value": 90},
                {"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": ">", "value": 10},
            ],
        }
        result = evaluate_group(df, group, {})
        r1 = evaluate_rule(df, group["rules"][0], {})
        r2 = evaluate_rule(df, group["rules"][1], {})
        expected = r1 & r2
        pd.testing.assert_series_equal(result, expected, check_names=False)

    def test_or_logic(self, df):
        group = {
            "logic": "OR",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": "<", "value": 30},
                {"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": ">", "value": 70},
            ],
        }
        result = evaluate_group(df, group, {})
        assert result.dtype == bool

    def test_empty_rules_returns_false(self, df):
        group = {"logic": "AND", "rules": []}
        result = evaluate_group(df, group, {})
        assert (result == False).all()

    def test_single_rule_group(self, df):
        rule = {"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": "<", "value": 50}
        group = {"logic": "AND", "rules": [rule]}
        result = evaluate_group(df, group, {})
        expected = evaluate_rule(df, rule, {})
        pd.testing.assert_series_equal(result, expected, check_names=False)


# ── Filter evaluation tests ────────────────────────────────────────

class TestEvaluateFilters:
    def test_empty_filters_returns_true(self, df):
        result = evaluate_filters(df, [], {})
        assert result.all()

    def test_single_filter(self, df):
        filters = [
            {"type": "volume_filter", "indicator": "volume", "params": {}, "operator": ">", "value": 0},
        ]
        result = evaluate_filters(df, filters, {})
        assert result.all()

    def test_multiple_filters_and(self, df):
        median_vol = df["volume"].median()
        filters = [
            {"type": "volume_filter", "indicator": "volume", "params": {}, "operator": ">", "value": median_vol},
            {"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": "<", "value": 90},
        ]
        result = evaluate_filters(df, filters, {})
        assert result.dtype == bool
        assert result.sum() < len(df)


# ── compute_all_indicators tests ────────────────────────────────────

class TestComputeAllIndicators:
    def test_collects_indicators_from_entry_exit_filters(self, df):
        rules_dict = {
            "entry": {
                "rules": [
                    {"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": "<", "value": 30},
                ]
            },
            "exit": {
                "rules": [
                    {"type": "indicator_threshold", "indicator": "ema", "params": {"period": 20}, "operator": ">", "value": 100},
                ]
            },
            "filters": [
                {"type": "volume_filter", "indicator": "volume_sma", "params": {"period": 20}, "operator": ">", "value": 1e6},
            ],
        }
        cache = compute_all_indicators(df, rules_dict)
        assert len(cache) == 3

    def test_cross_indicators_cached(self, df):
        rules_dict = {
            "entry": {
                "rules": [
                    {
                        "type": "indicator_cross",
                        "indicator": "ema", "params": {"period": 12},
                        "cross_indicator": "ema", "cross_params": {"period": 26},
                        "direction": "crosses_above",
                    },
                ]
            },
            "exit": {"rules": [{"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": ">", "value": 70}]},
            "filters": [],
        }
        cache = compute_all_indicators(df, rules_dict)
        assert len(cache) == 3


# ── Fail-closed tests ──────────────────────────────────────────────

class TestFailClosed:
    def test_unknown_indicator_in_rule(self, df):
        rule = {
            "type": "indicator_threshold",
            "indicator": "mystery_indicator",
            "params": {},
            "operator": "<",
            "value": 50,
        }
        result = evaluate_rule(df, rule, {})
        assert (result == False).all()

    def test_unknown_operator_in_rule(self, df):
        rule = {
            "type": "indicator_threshold",
            "indicator": "rsi",
            "params": {"period": 14},
            "operator": "invalid_op",
            "value": 50,
        }
        result = evaluate_rule(df, rule, {})
        assert (result == False).all()

    def test_unknown_rule_type(self, df):
        rule = {"type": "future_rule_type_v3"}
        result = evaluate_rule(df, rule, {})
        assert (result == False).all()
