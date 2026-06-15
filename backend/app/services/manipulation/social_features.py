"""Social feature computation (Layer D) — KOL pump, retail FOMO, sentiment extremes."""
from __future__ import annotations

import math
from typing import Any


def _safe_div(a: float, b: float) -> float:
    return a / b if b != 0 else 0.0


def _clamp(val: float, lo: float = 0.0, hi: float = 100.0) -> float:
    return max(lo, min(hi, val))


def _mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def _std(values: list[float]) -> float:
    if len(values) < 2:
        return 0.0
    m = _mean(values)
    variance = sum((v - m) ** 2 for v in values) / len(values)
    return math.sqrt(variance) if variance > 0 else 0.0


def social_mention_velocity(snapshots: list[dict], window: int = 12) -> float:
    """How fast mentions are accelerating vs baseline.

    Compares recent window mention velocity against the earlier baseline.
    High values indicate sudden social attention surge.
    """
    if len(snapshots) < window + 5:
        return 0.0
    recent = [s.get("mention_velocity", 1.0) for s in snapshots[-window:]]
    baseline = [s.get("mention_velocity", 1.0) for s in snapshots[:-(window)]]
    if not baseline:
        return 0.0
    baseline_mean = _mean(baseline)
    baseline_std = _std(baseline)
    recent_mean = _mean(recent)

    if baseline_std == 0:
        # No variance in baseline — use ratio
        ratio = _safe_div(recent_mean, max(baseline_mean, 0.1))
        return _clamp(min(ratio * 25, 100))

    z = (recent_mean - baseline_mean) / baseline_std
    return _clamp(min(max(z, 0) * 20, 100))


def kol_pump_score(snapshots: list[dict], window: int = 12) -> float:
    """KOL mentions concentrated in a short window with high follower reach.

    Detects coordinated KOL campaigns: multiple KOL mentions appearing in a
    concentrated burst, especially with large follower counts.
    """
    if len(snapshots) < window:
        return 0.0
    recent = snapshots[-window:]
    baseline = snapshots[:-window] if len(snapshots) > window else []

    # KOL mention concentration in recent window
    recent_kol_total = sum(s.get("kol_mention_count", 0) for s in recent)
    baseline_kol_avg = _mean([s.get("kol_mention_count", 0) for s in baseline]) * window if baseline else 1.0

    kol_surge = _safe_div(recent_kol_total, max(baseline_kol_avg, 1.0))

    # Follower reach amplification
    kol_entries = [s for s in recent if s.get("kol_mention_count", 0) > 0]
    avg_followers = _mean([s.get("kol_avg_followers", 0) for s in kol_entries]) if kol_entries else 0
    follower_score = min(avg_followers / 1_000_000, 1.0)  # normalized to 1M

    # Combined: surge * reach
    raw = kol_surge * 20 * (0.5 + follower_score * 0.5)
    return _clamp(raw)


def sentiment_extreme_score(snapshots: list[dict]) -> float:
    """Sentiment at extreme positive (FOMO) or negative (FUD).

    Measures how far the latest sentiment and fear/greed are from neutral.
    Extreme optimism during a pump = distribution risk.
    """
    if not snapshots:
        return 0.0
    recent = snapshots[-6:] if len(snapshots) >= 6 else snapshots
    sentiments = [s.get("sentiment_score", 0) for s in recent]
    fgi_values = [s.get("fear_greed_index", 50) for s in recent]

    avg_sentiment = _mean(sentiments)
    avg_fgi = _mean(fgi_values)

    # Extreme positive sentiment (FOMO) or extreme negative (FUD)
    sentiment_extremity = abs(avg_sentiment) * 100  # 0-100
    fgi_extremity = abs(avg_fgi - 50) * 2  # 0-100

    return _clamp((sentiment_extremity * 0.6 + fgi_extremity * 0.4))


def retail_fomo_score(snapshots: list[dict], window: int = 12) -> float:
    """Mention velocity + sentiment extreme + google trend spike together.

    When all three are elevated simultaneously, retail FOMO is in full effect.
    This is the "greater fool" phase of a KOL pump.
    """
    if len(snapshots) < window:
        return 0.0
    mention_vel = social_mention_velocity(snapshots, window=window)
    sentiment_ext = sentiment_extreme_score(snapshots)

    # Google trend spike in recent window
    recent = snapshots[-window:]
    trend_values = [s.get("google_trend_zscore", 0) for s in recent]
    trend_peak = max(trend_values) if trend_values else 0.0
    trend_score = _clamp(min(max(trend_peak, 0) * 25, 100))

    # Telegram velocity surge
    tg_vels = [s.get("telegram_message_velocity", 1.0) for s in recent]
    tg_peak = max(tg_vels) if tg_vels else 1.0
    tg_score = _clamp(min(max(tg_peak - 1.0, 0) * 15, 100))

    # All signals together = FOMO
    raw = mention_vel * 0.30 + sentiment_ext * 0.25 + trend_score * 0.25 + tg_score * 0.20
    return _clamp(raw)


def social_price_divergence(snapshots: list[dict], window: int = 12) -> float:
    """Social hype declining but still elevated — distribution phase signal.

    When KOLs have gone silent, mentions are fading from peak, but overall
    social activity is still above baseline = insiders distributing to retail.
    """
    if len(snapshots) < window + 5:
        return 0.0
    recent = snapshots[-window:]
    earlier = snapshots[-(window * 2):-window] if len(snapshots) >= window * 2 else snapshots[:len(snapshots) - window]

    if not earlier:
        return 0.0

    # Mention velocity trend: compare recent half vs earlier half
    recent_vel = _mean([s.get("mention_velocity", 1.0) for s in recent])
    earlier_vel = _mean([s.get("mention_velocity", 1.0) for s in earlier])

    # KOL activity: silence in recent period vs earlier
    recent_kol = _mean([s.get("kol_mention_count", 0) for s in recent])
    earlier_kol = _mean([s.get("kol_mention_count", 0) for s in earlier])

    # Baseline (first quarter of all data)
    baseline_len = max(len(snapshots) // 4, 1)
    baseline = snapshots[:baseline_len]
    baseline_vel = _mean([s.get("mention_velocity", 1.0) for s in baseline])

    # Divergence: mentions declining from peak but still elevated vs baseline
    declining = earlier_vel > recent_vel  # mentions are dropping
    still_elevated = recent_vel > baseline_vel * 1.5  # but still above normal
    kol_silent = recent_kol < earlier_kol * 0.5 if earlier_kol > 0 else False  # KOLs have left

    if not declining or not still_elevated:
        return 0.0

    decline_ratio = _safe_div(earlier_vel - recent_vel, earlier_vel)
    elevation_ratio = _safe_div(recent_vel, max(baseline_vel, 0.1))
    kol_drop = _safe_div(max(earlier_kol - recent_kol, 0), max(earlier_kol, 1))

    raw = (decline_ratio * 30 + min(elevation_ratio * 10, 40) + kol_drop * 30)
    return _clamp(raw)


def compute_social_features(snapshots: list[dict]) -> dict[str, float]:
    """Compute all Layer D features from social snapshot history."""
    return {
        "social_mention_velocity": social_mention_velocity(snapshots),
        "kol_pump_score": kol_pump_score(snapshots),
        "sentiment_extreme_score": sentiment_extreme_score(snapshots),
        "retail_fomo_score": retail_fomo_score(snapshots),
        "social_price_divergence": social_price_divergence(snapshots),
    }
