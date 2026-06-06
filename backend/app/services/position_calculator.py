from __future__ import annotations

from dataclasses import dataclass


@dataclass
class PositionSizeResult:
    position_size: float
    position_pct: float
    risk_amount: float
    stop_distance: float
    stop_distance_pct: float
    method: str


def calculate_position_size(
    account_equity: float,
    risk_per_trade: float,
    entry_price: float,
    stop_price: float,
    max_position_pct: float = 0.1,
    ai_size_multiplier: float = 1.0,
    leverage: float = 1.0,
) -> PositionSizeResult:
    if account_equity <= 0 or entry_price <= 0:
        return PositionSizeResult(
            position_size=0, position_pct=0, risk_amount=0,
            stop_distance=0, stop_distance_pct=0, method="invalid_input",
        )

    risk_budget = account_equity * risk_per_trade
    stop_distance = abs(entry_price - stop_price)
    stop_distance_pct = stop_distance / entry_price if entry_price > 0 else 0

    if stop_distance < entry_price * 1e-6:
        pct = min(max_position_pct, risk_per_trade) * ai_size_multiplier
        size = (account_equity * pct * leverage) / entry_price
        return PositionSizeResult(
            position_size=size, position_pct=pct,
            risk_amount=risk_budget * ai_size_multiplier,
            stop_distance=0, stop_distance_pct=0,
            method="fixed_pct_fallback",
        )

    raw_size = risk_budget / stop_distance
    raw_size *= ai_size_multiplier * leverage

    position_value = raw_size * entry_price
    position_pct = position_value / account_equity if account_equity > 0 else 0

    if position_pct > max_position_pct:
        position_pct = max_position_pct
        position_value = account_equity * position_pct
        raw_size = position_value / entry_price

    actual_risk = raw_size * stop_distance

    return PositionSizeResult(
        position_size=round(raw_size, 8),
        position_pct=round(position_pct, 6),
        risk_amount=round(actual_risk, 2),
        stop_distance=round(stop_distance, 2),
        stop_distance_pct=round(stop_distance_pct, 6),
        method="risk_based",
    )
