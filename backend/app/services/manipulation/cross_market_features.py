"""Cross-market feature computation (Layer E) — basis, funding, OI, liquidation signals."""
from __future__ import annotations

import math
from typing import Any


def _safe_div(a: float, b: float) -> float:
    return a / b if b != 0 else 0.0


def _clamp(val: float, lo: float = 0.0, hi: float = 100.0) -> float:
    return max(lo, min(hi, val))


def _zscore(values: list[float], latest: float) -> float:
    if len(values) < 5:
        return 0.0
    mean = sum(values) / len(values)
    variance = sum((v - mean) ** 2 for v in values) / len(values)
    std = math.sqrt(variance) if variance > 0 else 0.0
    if std == 0:
        return 0.0
    return (latest - mean) / std


def funding_rate_zscore(snapshots: list[dict], window: int = 30) -> float:
    """How extreme is the current funding rate vs recent history."""
    if len(snapshots) < window + 1:
        return 0.0
    rates = [s.get("funding_rate", 0) for s in snapshots[-(window + 1):]]
    z = _zscore(rates[:-1], rates[-1])
    return _clamp(min(abs(z) * 20, 100))


def basis_zscore(snapshots: list[dict], window: int = 30) -> float:
    """How extreme is the spot-perp basis vs recent history."""
    if len(snapshots) < window + 1:
        return 0.0
    bases = [s.get("basis_pct", 0) for s in snapshots[-(window + 1):]]
    z = _zscore(bases[:-1], bases[-1])
    return _clamp(min(abs(z) * 20, 100))


def oi_surge_score(snapshots: list[dict], window: int = 10) -> float:
    """Rapid OI increase — indicates new positions flooding in (leverage buildup)."""
    if len(snapshots) < window + 1:
        return 0.0
    ois = [s.get("open_interest", 0) for s in snapshots[-(window + 1):]]
    if ois[0] == 0:
        return 0.0
    change = (ois[-1] - ois[0]) / ois[0]
    return _clamp(max(0, change * 200))


def liquidation_imbalance(snapshots: list[dict]) -> float:
    """Asymmetry between long and short liquidations — signals a squeeze."""
    if not snapshots:
        return 0.0
    latest = snapshots[-1]
    long_liq = latest.get("liquidation_24h_long", 0)
    short_liq = latest.get("liquidation_24h_short", 0)
    total = long_liq + short_liq
    if total == 0:
        return 0.0
    imbalance = abs(long_liq - short_liq) / total
    return _clamp(imbalance * 100)


def long_short_extreme(snapshots: list[dict]) -> float:
    """How extreme is the long/short ratio — crowded trades are vulnerable."""
    if not snapshots:
        return 0.0
    ratio = snapshots[-1].get("long_short_ratio", 1.0)
    deviation = abs(ratio - 1.0)
    return _clamp(deviation * 100)


def cross_market_squeeze_score(snapshots: list[dict]) -> float:
    """Composite: extreme funding + OI surge + liquidation imbalance = squeeze setup.
    This is the primary M5 detection signal."""
    if len(snapshots) < 10:
        return 0.0
    fr = funding_rate_zscore(snapshots)
    basis = basis_zscore(snapshots)
    oi = oi_surge_score(snapshots)
    liq = liquidation_imbalance(snapshots)
    # Weighted: funding and basis are strongest signals
    score = fr * 0.30 + basis * 0.25 + oi * 0.25 + liq * 0.20
    return _clamp(score)


def compute_cross_market_features(snapshots: list[dict]) -> dict[str, float]:
    """Compute all Layer E features from cross-market snapshot history."""
    return {
        "funding_rate_zscore": funding_rate_zscore(snapshots),
        "basis_zscore": basis_zscore(snapshots),
        "oi_surge_score": oi_surge_score(snapshots),
        "liquidation_imbalance": liquidation_imbalance(snapshots),
        "long_short_extreme": long_short_extreme(snapshots),
        "cross_market_squeeze_score": cross_market_squeeze_score(snapshots),
    }
