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


def consolidation_score(candles: list[dict[str, Any]], window: int = 20) -> float:
    """Price compression indicator — building position (accumulation) signal.
    High score = price range narrowing + volume declining."""
    if len(candles) < window:
        return 0.0
    recent = candles[-window:]
    ranges = [(c["high"] - c["low"]) / c["close"] if c["close"] > 0 else 0 for c in recent]
    volumes = [c["volume"] for c in recent]

    # Check if ranges are decreasing (narrowing)
    first_half_range = sum(ranges[:window // 2]) / (window // 2)
    second_half_range = sum(ranges[window // 2:]) / (window // 2)
    range_contraction = _safe_div(first_half_range - second_half_range, first_half_range) if first_half_range > 0 else 0

    # Check if volume is declining
    first_half_vol = sum(volumes[:window // 2]) / (window // 2)
    second_half_vol = sum(volumes[window // 2:]) / (window // 2)
    vol_decline = _safe_div(first_half_vol - second_half_vol, first_half_vol) if first_half_vol > 0 else 0

    score = (max(0, range_contraction) * 60 + max(0, vol_decline) * 40)
    return _clamp(score)


def breakout_velocity(candles: list[dict[str, Any]], window: int = 5) -> float:
    """Breakout speed indicator — markup phase signal.
    High score = rapid price acceleration with volume surge."""
    if len(candles) < window + 5:
        return 0.0
    recent = candles[-window:]
    prior = candles[-(window + 5):-window]

    # Price change in recent window
    price_change = _safe_div(recent[-1]["close"] - recent[0]["open"], recent[0]["open"]) if recent[0]["open"] > 0 else 0

    # Compare to prior period volatility
    prior_changes = [abs(c["close"] - c["open"]) / c["open"] if c["open"] > 0 else 0 for c in prior]
    prior_avg_change = sum(prior_changes) / len(prior_changes) if prior_changes else 0

    # Acceleration = how much faster is current move vs prior
    acceleration = _safe_div(abs(price_change), prior_avg_change) if prior_avg_change > 0 else 0

    # Volume confirmation
    recent_vol = sum(c["volume"] for c in recent) / len(recent)
    prior_vol = sum(c["volume"] for c in prior) / len(prior) if prior else 1
    vol_ratio = _safe_div(recent_vol, prior_vol)

    score = min(acceleration * 15, 70) + min((vol_ratio - 1) * 30, 30)
    return _clamp(max(0, score))


def distribution_signature(candles: list[dict[str, Any]], window: int = 10) -> float:
    """Distribution phase indicator — high volume but price stagnation or decline.
    High score = volume up but price flat/dropping (smart money exiting)."""
    if len(candles) < window:
        return 0.0
    recent = candles[-window:]

    # Volume trend (should be elevated)
    volumes = [c["volume"] for c in recent]
    vol_mean = sum(volumes) / len(volumes)
    all_volumes = [c["volume"] for c in candles]
    overall_mean = sum(all_volumes) / len(all_volumes) if all_volumes else 1
    vol_elevated = _safe_div(vol_mean, overall_mean)

    # Price trend (should be flat or declining)
    price_change = _safe_div(recent[-1]["close"] - recent[0]["open"], recent[0]["open"]) if recent[0]["open"] > 0 else 0

    # Multiple attempts to break higher but failing
    highs = [c["high"] for c in recent]
    max_high = max(highs)
    attempts_near_high = sum(1 for h in highs if h > max_high * 0.98)

    score = 0
    if vol_elevated > 1.3 and price_change < 0.02:
        score += min((vol_elevated - 1) * 40, 50)
    if price_change < -0.01:
        score += min(abs(price_change) * 500, 25)
    if attempts_near_high >= 3:
        score += 25

    return _clamp(score)


def compute_all_features(candles: list[dict[str, Any]]) -> dict[str, float]:
    return {
        # existing 8 features
        "wick_ratio_up": wick_ratio_up(candles),
        "wick_ratio_down": wick_ratio_down(candles),
        "volume_zscore": volume_zscore(candles),
        "price_range_spike": price_range_spike(candles),
        "pump_then_dump": pump_then_dump(candles),
        "dump_then_recover": dump_then_recover(candles),
        "pinbar_score": pinbar_score(candles),
        "volume_price_divergence": volume_price_divergence(candles),
        # new lifecycle features
        "consolidation_score": consolidation_score(candles),
        "breakout_velocity": breakout_velocity(candles),
        "distribution_signature": distribution_signature(candles),
    }
