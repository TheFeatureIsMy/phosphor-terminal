from __future__ import annotations


def calculate_slippage(
    signal_price: float,
    filled_price: float,
    spread_cost: float = 0,
    market_impact: float = 0,
    latency_cost: float = 0,
) -> dict:
    execution_slippage = filled_price - signal_price
    slippage_pct = (execution_slippage / signal_price * 100) if signal_price else 0
    total_cost = abs(execution_slippage) + spread_cost + market_impact + latency_cost
    if abs(slippage_pct) < 0.05:
        diagnosis = "execution_within_tolerance"
    elif total_cost > abs(execution_slippage) * 1.5:
        diagnosis = "execution_costs_dominated"
    elif execution_slippage > 0:
        diagnosis = "negative_buy_slippage_or_positive_sell_improvement"
    else:
        diagnosis = "positive_buy_improvement_or_negative_sell_slippage"
    return {
        "execution_slippage": round(execution_slippage, 8),
        "slippage_pct": round(slippage_pct, 6),
        "diagnosis": diagnosis,
    }
