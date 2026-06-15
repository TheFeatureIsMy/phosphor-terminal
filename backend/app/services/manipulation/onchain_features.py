"""On-chain feature computation (Layer C) — holder concentration, exchange flow, whale activity."""
from __future__ import annotations

import math


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


def holder_concentration_score(snapshots: list[dict]) -> float:
    """High top-10 holder concentration = few wallets control supply.
    >60% top_10 = high score, <30% = low score."""
    if not snapshots:
        return 0.0
    latest = snapshots[-1]
    pct = latest.get("top_10_holder_pct", 0)
    # Linear scale: 30% -> 0, 60% -> 50, 90% -> 100
    score = max(0, (pct - 30)) * (100 / 60)
    return _clamp(score)


def holder_concentration_delta(snapshots: list[dict], window: int = 10) -> float:
    """Rate of change of top-10 concentration over window.
    Increasing concentration = accumulation pattern."""
    if len(snapshots) < window:
        return 0.0
    recent = snapshots[-window:]
    start_pct = recent[0].get("top_10_holder_pct", 0)
    end_pct = recent[-1].get("top_10_holder_pct", 0)
    if start_pct == 0:
        return 0.0
    delta_pct = ((end_pct - start_pct) / start_pct) * 100
    # Scale: 0% change -> 0, 20%+ change -> 100
    score = max(0, delta_pct) * 5
    return _clamp(score)


def exchange_inflow_zscore(snapshots: list[dict], window: int = 20) -> float:
    """Sudden exchange inflow spike vs history — pre-dump signal.
    Whales depositing tokens to exchanges to prepare for selling."""
    if len(snapshots) < window + 1:
        return 0.0
    inflows = [s.get("exchange_inflow_24h", 0) for s in snapshots[-(window + 1):]]
    z = _zscore(inflows[:-1], inflows[-1])
    return _clamp(min(abs(z) * 20, 100))


def whale_activity_score(snapshots: list[dict], window: int = 10) -> float:
    """Elevated whale transfer count relative to history."""
    if len(snapshots) < window:
        return 0.0
    recent = snapshots[-window:]
    counts = [s.get("whale_transfer_count", 0) for s in recent]
    avg = sum(counts) / len(counts)
    # Scale: 0 transfers -> 0, 15+ average -> 100
    return _clamp(min(avg * 6.67, 100))


def new_holder_velocity(snapshots: list[dict], window: int = 10) -> float:
    """Rapid new holder increase — signals retail FOMO.
    Compares recent window average to earlier baseline."""
    if len(snapshots) < window * 2:
        return 0.0
    baseline = snapshots[-(window * 2):-window]
    recent = snapshots[-window:]
    baseline_avg = sum(s.get("new_holders_24h", 0) for s in baseline) / len(baseline)
    recent_avg = sum(s.get("new_holders_24h", 0) for s in recent) / len(recent)
    if baseline_avg == 0:
        return 0.0
    ratio = recent_avg / baseline_avg
    # Scale: 1x = 0 (no change), 3x+ = 100
    score = max(0, (ratio - 1)) * 50
    return _clamp(score)


def compute_onchain_features(snapshots: list[dict]) -> dict[str, float]:
    """Compute all Layer C features from on-chain snapshot history."""
    return {
        "holder_concentration_score": holder_concentration_score(snapshots),
        "holder_concentration_delta": holder_concentration_delta(snapshots),
        "exchange_inflow_zscore": exchange_inflow_zscore(snapshots),
        "whale_activity_score": whale_activity_score(snapshots),
        "new_holder_velocity": new_holder_velocity(snapshots),
    }
