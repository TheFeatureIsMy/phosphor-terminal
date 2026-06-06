"""OHLCV-derived manipulation features — Layer A pure computation."""
from __future__ import annotations

import math
from typing import Any


def _safe_div(a: float, b: float) -> float:
    return a / b if b != 0 else 0.0


def _clamp(val: float, lo: float = 0.0, hi: float = 100.0) -> float:
    return max(lo, min(hi, val))


def wick_ratio_up(candles: list[dict[str, Any]], window: int = 5) -> float:
    if len(candles) < window:
        return 0.0
    recent = candles[-window:]
    ratios = []
    for c in recent:
        high, close, open_ = c["high"], c["close"], c["open"]
        body_top = max(close, open_)
        body_size = abs(close - open_)
        upper_wick = high - body_top
        ratios.append(_safe_div(upper_wick, body_size) if body_size > 0 else 0.0)
    avg = sum(ratios) / len(ratios)
    return _clamp(min(avg * 20, 100))


def wick_ratio_down(candles: list[dict[str, Any]], window: int = 5) -> float:
    if len(candles) < window:
        return 0.0
    recent = candles[-window:]
    ratios = []
    for c in recent:
        low, close, open_ = c["low"], c["close"], c["open"]
        body_bottom = min(close, open_)
        body_size = abs(close - open_)
        lower_wick = body_bottom - low
        ratios.append(_safe_div(lower_wick, body_size) if body_size > 0 else 0.0)
    avg = sum(ratios) / len(ratios)
    return _clamp(min(avg * 20, 100))


def volume_zscore(candles: list[dict[str, Any]], window: int = 20) -> float:
    if len(candles) < window + 1:
        return 0.0
    volumes = [c["volume"] for c in candles[-(window + 1):]]
    hist = volumes[:-1]
    latest = volumes[-1]
    mean = sum(hist) / len(hist)
    var = sum((v - mean) ** 2 for v in hist) / len(hist)
    std = math.sqrt(var) if var > 0 else 0.0
    if std == 0:
        return 0.0
    z = (latest - mean) / std
    return _clamp(min(abs(z) * 20, 100))


def price_range_spike(candles: list[dict[str, Any]], window: int = 20) -> float:
    if len(candles) < window + 1:
        return 0.0
    ranges = []
    for c in candles[-(window + 1):]:
        close = c["close"]
        r = (c["high"] - c["low"]) / close if close > 0 else 0.0
        ranges.append(r)
    hist = ranges[:-1]
    latest = ranges[-1]
    mean = sum(hist) / len(hist) if hist else 0.0
    if mean == 0:
        return 0.0
    ratio = latest / mean
    return _clamp(min((ratio - 1) * 30, 100))


def pump_then_dump(candles: list[dict[str, Any]], window: int = 5) -> float:
    if len(candles) < window * 2:
        return 0.0
    recent = candles[-(window * 2):]
    first_half = recent[:window]
    second_half = recent[window:]
    up_moves = sum(max(0, c["close"] - c["open"]) for c in first_half)
    down_moves = sum(max(0, c["open"] - c["close"]) for c in second_half)
    avg_close = sum(c["close"] for c in recent) / len(recent)
    if avg_close == 0:
        return 0.0
    up_pct = up_moves / avg_close * 100
    down_pct = down_moves / avg_close * 100
    if up_pct > 2 and down_pct > 2:
        score = min((up_pct + down_pct) * 5, 100)
        return _clamp(score)
    return 0.0


def dump_then_recover(candles: list[dict[str, Any]], window: int = 5) -> float:
    if len(candles) < window * 2:
        return 0.0
    recent = candles[-(window * 2):]
    first_half = recent[:window]
    second_half = recent[window:]
    down_moves = sum(max(0, c["open"] - c["close"]) for c in first_half)
    up_moves = sum(max(0, c["close"] - c["open"]) for c in second_half)
    avg_close = sum(c["close"] for c in recent) / len(recent)
    if avg_close == 0:
        return 0.0
    down_pct = down_moves / avg_close * 100
    up_pct = up_moves / avg_close * 100
    if down_pct > 2 and up_pct > 2:
        score = min((down_pct + up_pct) * 5, 100)
        return _clamp(score)
    return 0.0


def pinbar_score(candles: list[dict[str, Any]], window: int = 5) -> float:
    if len(candles) < window:
        return 0.0
    recent = candles[-window:]
    scores = []
    for c in recent:
        high, low, close, open_ = c["high"], c["low"], c["close"], c["open"]
        total_range = high - low
        if total_range == 0:
            scores.append(0.0)
            continue
        body = abs(close - open_)
        body_ratio = body / total_range
        upper_wick = high - max(close, open_)
        lower_wick = min(close, open_) - low
        max_wick = max(upper_wick, lower_wick)
        min_wick = min(upper_wick, lower_wick)
        if body_ratio < 0.3 and max_wick > min_wick * 1.5:
            wick_ratio = max_wick / total_range
            scores.append(wick_ratio * 100)
        else:
            scores.append(0.0)
    return _clamp(sum(scores) / len(scores))


def volume_price_divergence(candles: list[dict[str, Any]], window: int = 10) -> float:
    if len(candles) < window:
        return 0.0
    recent = candles[-window:]
    vol_changes = []
    price_changes = []
    for i in range(1, len(recent)):
        prev, curr = recent[i - 1], recent[i]
        if prev["volume"] > 0:
            vol_changes.append((curr["volume"] - prev["volume"]) / prev["volume"])
        else:
            vol_changes.append(0.0)
        if prev["close"] > 0:
            price_changes.append((curr["close"] - prev["close"]) / prev["close"])
        else:
            price_changes.append(0.0)
    if not vol_changes:
        return 0.0
    avg_vol_change = sum(vol_changes) / len(vol_changes)
    avg_price_change = sum(price_changes) / len(price_changes)
    if avg_vol_change > 0.1 and abs(avg_price_change) < 0.01:
        return _clamp(avg_vol_change * 100)
    if avg_vol_change > 0.1 and avg_price_change < -0.01:
        return _clamp((avg_vol_change + abs(avg_price_change)) * 80)
    return 0.0


def compute_all_features(candles: list[dict[str, Any]]) -> dict[str, float]:
    return {
        "wick_ratio_up": wick_ratio_up(candles),
        "wick_ratio_down": wick_ratio_down(candles),
        "volume_zscore": volume_zscore(candles),
        "price_range_spike": price_range_spike(candles),
        "pump_then_dump": pump_then_dump(candles),
        "dump_then_recover": dump_then_recover(candles),
        "pinbar_score": pinbar_score(candles),
        "volume_price_divergence": volume_price_divergence(candles),
    }
