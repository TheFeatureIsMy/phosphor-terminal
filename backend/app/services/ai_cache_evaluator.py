from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Literal

from app.domain.dsl import DegradationPolicy

ACTION_MULTIPLIERS = {
    "reduce_size": 0.5,
    "block_new_entries": 0.0,
    "ignore": 1.0,
}


@dataclass
class AICacheEvaluation:
    cache_state: Literal["fresh", "soft_expired", "hard_expired", "missing"]
    action: Literal["normal", "reduce_size", "block_new_entries", "ignore"]
    size_multiplier: float
    reason: str


def evaluate_ai_cache(
    cache: dict | None,
    degradation_policy: DegradationPolicy | None = None,
    soft_ttl_s: int = 600,
    hard_ttl_s: int = 900,
) -> AICacheEvaluation:
    if degradation_policy is None:
        degradation_policy = DegradationPolicy()

    if not cache:
        return AICacheEvaluation(
            cache_state="missing",
            action="reduce_size",
            size_multiplier=0.5,
            reason="ai_cache_missing_conservative_mode",
        )

    generated_at_str = cache.get("generated_at")
    if not generated_at_str:
        return AICacheEvaluation(
            cache_state="missing",
            action="reduce_size",
            size_multiplier=0.5,
            reason="ai_cache_no_timestamp",
        )

    try:
        generated_at = datetime.fromisoformat(generated_at_str)
    except (ValueError, TypeError):
        return AICacheEvaluation(
            cache_state="missing",
            action="reduce_size",
            size_multiplier=0.5,
            reason="ai_cache_invalid_timestamp",
        )

    now = datetime.now(timezone.utc)
    if generated_at.tzinfo is None:
        generated_at = generated_at.replace(tzinfo=timezone.utc)
    elapsed_s = (now - generated_at).total_seconds()

    # Hard block from AI
    if cache.get("trade_permission") == "block_new_entries":
        return AICacheEvaluation(
            cache_state="fresh" if elapsed_s <= soft_ttl_s else "soft_expired",
            action="block_new_entries",
            size_multiplier=0.0,
            reason="ai_slow_track_hard_blocked",
        )

    if elapsed_s <= soft_ttl_s:
        risk = cache.get("ai_risk_score", 0.0)
        if risk > 0.65:
            multiplier = max(0.3, 1.0 - (risk - 0.5) * 2)
            return AICacheEvaluation(
                cache_state="fresh",
                action="reduce_size",
                size_multiplier=multiplier,
                reason="ai_risk_score_elevated",
            )
        return AICacheEvaluation(
            cache_state="fresh",
            action="normal",
            size_multiplier=1.0,
            reason="ai_cache_fresh",
        )

    if elapsed_s <= hard_ttl_s:
        policy_action = degradation_policy.ai_cache_soft_expired
        return AICacheEvaluation(
            cache_state="soft_expired",
            action=policy_action,
            size_multiplier=ACTION_MULTIPLIERS.get(policy_action, 0.5),
            reason="ai_cache_soft_expired",
        )

    policy_action = degradation_policy.ai_cache_hard_expired
    return AICacheEvaluation(
        cache_state="hard_expired",
        action=policy_action,
        size_multiplier=ACTION_MULTIPLIERS.get(policy_action, 0.0),
        reason="ai_cache_hard_expired",
    )
