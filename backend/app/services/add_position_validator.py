from __future__ import annotations

from dataclasses import dataclass, field

from app.domain.dsl import AddPositionPolicy
from app.services.blended_entry import calculate_blended_entry, calculate_total_risk


@dataclass
class AddPositionRequest:
    current_size: float
    current_avg_entry: float
    current_stop: float
    current_add_count: int
    add_entry_price: float
    add_size: float
    new_structural_stop: float
    account_equity: float
    policy: AddPositionPolicy
    structure_valid: bool
    structure_signal_confirmed: bool
    direction: str = "long"
    take_profit_price: float | None = None
    liquidation_price: float | None = None


@dataclass
class AddPositionValidation:
    allowed: bool
    reject_reasons: list[str] = field(default_factory=list)
    blended_avg_entry: float = 0.0
    total_size: float = 0.0
    total_risk_after_add: float = 0.0
    risk_budget: float = 0.0
    reward_risk_ratio: float | None = None
    liquidation_distance_pct: float | None = None


def validate_add_position(request: AddPositionRequest) -> AddPositionValidation:
    reasons = []
    policy = request.policy

    # 1. DCA policy check
    if not policy.allow_structure_add and not policy.allow_dca:
        reasons.append("position_adding_not_allowed")

    # 2. Structure validity
    if not request.structure_valid:
        reasons.append("structure_invalidated")

    # 3. Structure signal confirmed
    if policy.allow_structure_add and not request.structure_signal_confirmed:
        reasons.append("no_confirmed_structure_signal")

    # 4. Max add count
    if request.current_add_count >= policy.max_add_count:
        reasons.append("max_add_count_reached")

    # 5. Breakeven check
    if policy.require_stop_above_breakeven:
        if request.direction == "long":
            if request.current_stop < request.current_avg_entry:
                reasons.append("stop_below_breakeven")
        else:
            if request.current_stop > request.current_avg_entry:
                reasons.append("stop_above_breakeven")

    # Calculate blended entry
    blended = calculate_blended_entry(
        request.current_size, request.current_avg_entry,
        request.add_size, request.add_entry_price,
    )
    total_size = request.current_size + request.add_size

    # 6. Total risk after add
    risk_budget = request.account_equity * policy.max_total_risk_after_add
    total_risk = abs(calculate_total_risk(
        request.direction, blended,
        request.new_structural_stop, total_size,
    ))
    if total_risk > risk_budget:
        reasons.append("risk_budget_exceeded")

    # 7. R:R check
    rr = None
    if request.take_profit_price and total_risk > 0:
        if request.direction == "long":
            reward = (request.take_profit_price - blended) * total_size
        else:
            reward = (blended - request.take_profit_price) * total_size
        rr = reward / total_risk if total_risk > 0 else 0
        if rr < policy.min_reward_risk_after_add:
            reasons.append("reward_risk_too_low")

    # Liquidation distance
    liq_dist = None
    if request.liquidation_price and request.add_entry_price > 0:
        liq_dist = abs(request.add_entry_price - request.liquidation_price) / request.add_entry_price
        if liq_dist < policy.min_liquidation_distance_pct:
            reasons.append("liquidation_distance_unsafe")

    return AddPositionValidation(
        allowed=len(reasons) == 0,
        reject_reasons=reasons,
        blended_avg_entry=blended,
        total_size=total_size,
        total_risk_after_add=total_risk,
        risk_budget=risk_budget,
        reward_risk_ratio=rr,
        liquidation_distance_pct=liq_dist,
    )
