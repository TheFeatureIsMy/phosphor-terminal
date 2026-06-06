"""StrategyRuleDSL Interpreter — pure Python, no eval/exec, no Freqtrade dependency.

Evaluates validated RulePackage against pandas DataFrames.
All unknown indicators/operators fail closed (return False/NaN).
"""
from __future__ import annotations

import logging
import math
from typing import Any

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

SUPPORTED_SCHEMA_VERSIONS = {"2.5"}

# ── Indicator computation ───────────────────────────────────────────

def compute_indicator(df: pd.DataFrame, name: str, params: dict[str, Any]) -> pd.Series:
    try:
        return _INDICATOR_MAP[name](df, params)
    except KeyError:
        logger.warning("unknown indicator '%s', returning NaN", name)
        return pd.Series(np.nan, index=df.index)
    except Exception:
        logger.exception("error computing indicator '%s'", name)
        return pd.Series(np.nan, index=df.index)


def _rsi(df: pd.DataFrame, params: dict) -> pd.Series:
    period = int(params.get("period", 14))
    delta = df["close"].diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.ewm(alpha=1 / period, min_periods=period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1 / period, min_periods=period, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def _ema(df: pd.DataFrame, params: dict) -> pd.Series:
    period = int(params.get("period", 20))
    return df["close"].ewm(span=period, min_periods=period, adjust=False).mean()


def _sma(df: pd.DataFrame, params: dict) -> pd.Series:
    period = int(params.get("period", 20))
    return df["close"].rolling(window=period, min_periods=period).mean()


def _macd(df: pd.DataFrame, params: dict) -> pd.Series:
    fast = int(params.get("fast", 12))
    slow = int(params.get("slow", 26))
    ema_fast = df["close"].ewm(span=fast, min_periods=fast, adjust=False).mean()
    ema_slow = df["close"].ewm(span=slow, min_periods=slow, adjust=False).mean()
    return ema_fast - ema_slow


def _macd_signal(df: pd.DataFrame, params: dict) -> pd.Series:
    signal_period = int(params.get("signal", 9))
    macd_line = _macd(df, params)
    return macd_line.ewm(span=signal_period, min_periods=signal_period, adjust=False).mean()


def _bb_upper(df: pd.DataFrame, params: dict) -> pd.Series:
    period = int(params.get("period", 20))
    std_dev = float(params.get("std", 2.0))
    sma = df["close"].rolling(window=period, min_periods=period).mean()
    std = df["close"].rolling(window=period, min_periods=period).std()
    return sma + std_dev * std


def _bb_lower(df: pd.DataFrame, params: dict) -> pd.Series:
    period = int(params.get("period", 20))
    std_dev = float(params.get("std", 2.0))
    sma = df["close"].rolling(window=period, min_periods=period).mean()
    std = df["close"].rolling(window=period, min_periods=period).std()
    return sma - std_dev * std


def _atr(df: pd.DataFrame, params: dict) -> pd.Series:
    period = int(params.get("period", 14))
    high = df["high"]
    low = df["low"]
    prev_close = df["close"].shift(1)
    tr = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low - prev_close).abs(),
    ], axis=1).max(axis=1)
    return tr.rolling(window=period, min_periods=period).mean()


def _volume(df: pd.DataFrame, params: dict) -> pd.Series:
    return df["volume"].astype(float)


def _volume_sma(df: pd.DataFrame, params: dict) -> pd.Series:
    period = int(params.get("period", 20))
    return df["volume"].astype(float).rolling(window=period, min_periods=period).mean()


def _price_col(col: str):
    def _fn(df: pd.DataFrame, params: dict) -> pd.Series:
        return df[col].astype(float)
    return _fn


_INDICATOR_MAP = {
    "rsi": _rsi,
    "ema": _ema,
    "sma": _sma,
    "macd": _macd,
    "macd_signal": _macd_signal,
    "bb_upper": _bb_upper,
    "bb_lower": _bb_lower,
    "atr": _atr,
    "volume": _volume,
    "volume_sma": _volume_sma,
    "close": _price_col("close"),
    "open": _price_col("open"),
    "high": _price_col("high"),
    "low": _price_col("low"),
}


# ── Operator evaluation (vectorized) ───────────────────────────────

def apply_operator(series: pd.Series, operator: str, value: Any = None,
                   min_value: Any = None, max_value: Any = None,
                   other_series: pd.Series | None = None) -> pd.Series:
    try:
        return _OPERATOR_MAP[operator](series, value, min_value, max_value, other_series)
    except KeyError:
        logger.warning("unknown operator '%s', returning False", operator)
        return pd.Series(False, index=series.index)
    except Exception:
        logger.exception("error applying operator '%s'", operator)
        return pd.Series(False, index=series.index)


def _op_gt(s, v, *_): return s > v
def _op_gte(s, v, *_): return s >= v
def _op_lt(s, v, *_): return s < v
def _op_lte(s, v, *_): return s <= v
def _op_eq(s, v, *_): return s == v
def _op_neq(s, v, *_): return s != v

def _op_between(s, _v, mn, mx, *_): return (s >= mn) & (s <= mx)
def _op_not_between(s, _v, mn, mx, *_): return (s < mn) | (s > mx)

def _op_crosses_above(s, _v, _mn, _mx, other):
    prev_s = s.shift(1)
    prev_o = other.shift(1)
    return (prev_s <= prev_o) & (s > other)

def _op_crosses_below(s, _v, _mn, _mx, other):
    prev_s = s.shift(1)
    prev_o = other.shift(1)
    return (prev_s >= prev_o) & (s < other)


_OPERATOR_MAP = {
    ">": _op_gt, ">=": _op_gte, "<": _op_lt, "<=": _op_lte,
    "==": _op_eq, "!=": _op_neq,
    "between": _op_between, "not_between": _op_not_between,
    "crosses_above": _op_crosses_above, "crosses_below": _op_crosses_below,
}


# ── Rule evaluation ────────────────────────────────────────────────

def evaluate_rule(df: pd.DataFrame, rule: dict, indicator_cache: dict[str, pd.Series]) -> pd.Series:
    rule_type = rule.get("type", "")
    try:
        if rule_type == "indicator_threshold":
            return _eval_indicator_threshold(df, rule, indicator_cache)
        elif rule_type == "indicator_cross":
            return _eval_indicator_cross(df, rule, indicator_cache)
        elif rule_type in ("volume_filter", "volatility_filter"):
            return _eval_indicator_threshold(df, rule, indicator_cache)
        elif rule_type == "cooldown_filter":
            return pd.Series(True, index=df.index)
        elif rule_type in ("signal_confirmation", "manipulation_score_filter",
                           "portfolio_exposure_filter"):
            return pd.Series(True, index=df.index)
        else:
            logger.warning("unsupported rule type '%s', returning False", rule_type)
            return pd.Series(False, index=df.index)
    except Exception:
        logger.exception("error evaluating rule type '%s'", rule_type)
        return pd.Series(False, index=df.index)


def _get_indicator(df: pd.DataFrame, name: str, params: dict,
                   cache: dict[str, pd.Series]) -> pd.Series:
    key = f"{name}_{hash(frozenset(params.items()))}"
    if key not in cache:
        cache[key] = compute_indicator(df, name, params)
    return cache[key]


def _eval_indicator_threshold(df: pd.DataFrame, rule: dict,
                              cache: dict[str, pd.Series]) -> pd.Series:
    ind_name = rule.get("indicator", "")
    params = rule.get("params", {})
    series = _get_indicator(df, ind_name, params, cache)

    op = rule.get("operator", "")
    result = apply_operator(
        series, op,
        value=rule.get("value"),
        min_value=rule.get("min_value"),
        max_value=rule.get("max_value"),
    )
    return result.fillna(False).astype(bool)


def _eval_indicator_cross(df: pd.DataFrame, rule: dict,
                          cache: dict[str, pd.Series]) -> pd.Series:
    ind_a = _get_indicator(df, rule.get("indicator", ""), rule.get("params", {}), cache)
    ind_b = _get_indicator(df, rule.get("cross_indicator", ""), rule.get("cross_params", {}), cache)
    direction = rule.get("direction", "crosses_above")
    result = apply_operator(ind_a, direction, other_series=ind_b)
    return result.fillna(False).astype(bool)


# ── Group / Filter evaluation ──────────────────────────────────────

def evaluate_group(df: pd.DataFrame, group: dict,
                   indicator_cache: dict[str, pd.Series]) -> pd.Series:
    logic = group.get("logic", "AND")
    rules = group.get("rules", [])
    if not rules:
        return pd.Series(False, index=df.index)

    results = [evaluate_rule(df, r, indicator_cache) for r in rules]

    if logic == "AND":
        combined = results[0]
        for r in results[1:]:
            combined = combined & r
        return combined
    else:
        combined = results[0]
        for r in results[1:]:
            combined = combined | r
        return combined


def evaluate_filters(df: pd.DataFrame, filters: list[dict],
                     indicator_cache: dict[str, pd.Series]) -> pd.Series:
    if not filters:
        return pd.Series(True, index=df.index)
    results = [evaluate_rule(df, f, indicator_cache) for f in filters]
    combined = results[0]
    for r in results[1:]:
        combined = combined & r
    return combined


# ── Top-level evaluate ──────────────────────────────────────────────

def compute_all_indicators(df: pd.DataFrame, rules_dict: dict) -> dict[str, pd.Series]:
    cache: dict[str, pd.Series] = {}
    all_rules = []
    all_rules.extend(rules_dict.get("entry", {}).get("rules", []))
    all_rules.extend(rules_dict.get("exit", {}).get("rules", []))
    all_rules.extend(rules_dict.get("filters", []))

    for rule in all_rules:
        ind = rule.get("indicator")
        params = rule.get("params", {})
        if ind:
            _get_indicator(df, ind, params, cache)
        cross_ind = rule.get("cross_indicator")
        cross_params = rule.get("cross_params", {})
        if cross_ind:
            _get_indicator(df, cross_ind, cross_params, cache)

    return cache
