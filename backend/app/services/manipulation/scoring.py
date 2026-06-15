"""Manipulation scoring engine — aggregates features into sub-scores."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class ManipulationResult:
    symbol: str
    timeframe: str
    manipulation_score: float = 0.0
    stop_hunt_score: float = 0.0
    pump_dump_score: float = 0.0
    liquidity_trap_score: float = 0.0
    holder_concentration_score: float = 0.0
    funding_squeeze_score: float = 0.0
    risk_level: str = "low"
    features: dict[str, float] = field(default_factory=dict)
    reasoning: str = ""
    data_quality: dict[str, bool] = field(default_factory=dict)

    def to_scores_dict(self) -> dict[str, float]:
        return {
            "manipulation_score": self.manipulation_score,
            "stop_hunt_score": self.stop_hunt_score,
            "pump_dump_score": self.pump_dump_score,
            "liquidity_trap_score": self.liquidity_trap_score,
            "holder_concentration_score": self.holder_concentration_score,
            "funding_squeeze_score": self.funding_squeeze_score,
        }


def _weighted_avg(values: list[tuple[float, float]]) -> float:
    total_weight = sum(w for _, w in values)
    if total_weight == 0:
        return 0.0
    return sum(v * w for v, w in values) / total_weight


def _risk_level(score: float) -> str:
    if score >= 80:
        return "extreme"
    if score >= 60:
        return "high"
    if score >= 40:
        return "medium"
    return "low"


def compute_manipulation_scores(
    features: dict[str, float],
    symbol: str = "",
    timeframe: str = "1h",
    cross_market_features: dict[str, float] | None = None,
) -> ManipulationResult:
    stop_hunt = _weighted_avg([
        (features.get("wick_ratio_up", 0), 0.3),
        (features.get("wick_ratio_down", 0), 0.3),
        (features.get("volume_zscore", 0), 0.2),
        (features.get("pinbar_score", 0), 0.2),
    ])

    pump_dump = _weighted_avg([
        (features.get("pump_then_dump", 0), 0.5),
        (features.get("volume_price_divergence", 0), 0.3),
        (features.get("volume_zscore", 0), 0.2),
    ])

    liquidity_trap = _weighted_avg([
        (features.get("price_range_spike", 0), 0.4),
        (features.get("volume_zscore", 0), 0.3),
        (features.get("dump_then_recover", 0), 0.3),
    ])

    # Cross-market scores (Layer E)
    cm = cross_market_features or {}
    funding_squeeze = cm.get("cross_market_squeeze_score", 0)

    # Update overall score to include cross-market when available
    if cm:
        overall = _weighted_avg([
            (stop_hunt, 0.25),
            (pump_dump, 0.25),
            (liquidity_trap, 0.20),
            (funding_squeeze, 0.30),  # Cross-market gets highest weight when available
        ])
    else:
        overall = _weighted_avg([
            (stop_hunt, 0.35),
            (pump_dump, 0.35),
            (liquidity_trap, 0.30),
        ])

    risk = _risk_level(overall)

    reasons = []
    if stop_hunt > 60:
        reasons.append(f"stop_hunt elevated ({stop_hunt:.0f})")
    if pump_dump > 60:
        reasons.append(f"pump_dump pattern detected ({pump_dump:.0f})")
    if liquidity_trap > 60:
        reasons.append(f"liquidity trap signals ({liquidity_trap:.0f})")
    if funding_squeeze > 50:
        reasons.append(f"cross-market squeeze detected ({funding_squeeze:.0f})")
    if not reasons:
        reasons.append("no significant manipulation signals")

    return ManipulationResult(
        symbol=symbol,
        timeframe=timeframe,
        manipulation_score=round(overall, 1),
        stop_hunt_score=round(stop_hunt, 1),
        pump_dump_score=round(pump_dump, 1),
        liquidity_trap_score=round(liquidity_trap, 1),
        holder_concentration_score=0.0,
        funding_squeeze_score=round(funding_squeeze, 1),
        risk_level=risk,
        features=features,
        reasoning="; ".join(reasons),
        data_quality={"layer_a": True, "layer_b": False, "layer_c": False, "layer_e": bool(cm)},
    )
