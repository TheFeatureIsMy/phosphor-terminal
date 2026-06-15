"""Orderbook feature computation (Layer B) — spoofing, depth imbalance, liquidity voids."""
from __future__ import annotations

import math


def _clamp(val: float, lo: float = 0.0, hi: float = 100.0) -> float:
    return max(lo, min(hi, val))


def spoof_score(snapshots: list[dict], window: int = 20) -> float:
    """Detect spoofing: high cancel rate + large orders appearing/disappearing."""
    if len(snapshots) < window:
        return 0.0
    recent = snapshots[-window:]
    avg_cancel = sum(s.get("cancel_rate_5m", 0) for s in recent) / len(recent)
    avg_spoof = sum(s.get("spoof_pattern_count", 0) for s in recent) / len(recent)
    score = avg_cancel * 60 + min(avg_spoof * 10, 40)
    return _clamp(score)


def depth_imbalance_score(snapshots: list[dict]) -> float:
    """Detect orderbook imbalance — one side much heavier than other."""
    if not snapshots:
        return 0.0
    latest = snapshots[-1]
    ratio = latest.get("bid_depth_ratio", 0.5)
    imbalance = abs(ratio - 0.5) * 2  # 0 = balanced, 1 = fully one-sided
    return _clamp(imbalance * 100)


def liquidity_void_score(snapshots: list[dict]) -> float:
    """Detect gaps in orderbook — areas with no liquidity that price can jump through."""
    if not snapshots:
        return 0.0
    recent = snapshots[-5:] if len(snapshots) >= 5 else snapshots
    avg_void = sum(s.get("liquidity_void_depth", 0) for s in recent) / len(recent)
    return _clamp(min(avg_void * 30, 100))


def large_order_pressure(snapshots: list[dict], window: int = 10) -> float:
    """Detect unusual large order activity — potential manipulation setup."""
    if len(snapshots) < window:
        return 0.0
    recent = snapshots[-window:]
    avg_large = sum(s.get("large_order_count", 0) for s in recent) / len(recent)
    return _clamp(min(avg_large * 15, 100))


def spread_volatility(snapshots: list[dict], window: int = 20) -> float:
    """Rapid spread changes indicate orderbook manipulation."""
    if len(snapshots) < window:
        return 0.0
    spreads = [s.get("bid_ask_spread", 0) for s in snapshots[-window:]]
    mean = sum(spreads) / len(spreads)
    if mean == 0:
        return 0.0
    variance = sum((s - mean) ** 2 for s in spreads) / len(spreads)
    cv = math.sqrt(variance) / mean  # coefficient of variation
    return _clamp(min(cv * 50, 100))


def compute_orderbook_features(snapshots: list[dict]) -> dict[str, float]:
    return {
        "spoof_score": spoof_score(snapshots),
        "depth_imbalance_score": depth_imbalance_score(snapshots),
        "liquidity_void_score": liquidity_void_score(snapshots),
        "large_order_pressure": large_order_pressure(snapshots),
        "spread_volatility": spread_volatility(snapshots),
    }
