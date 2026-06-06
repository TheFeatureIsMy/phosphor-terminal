from __future__ import annotations

from dataclasses import dataclass


@dataclass
class LiquidityCheckResult:
    safe: bool
    liquidity_state: str  # normal, wide_spread, thin_depth
    spread_pct: float
    depth_score: float
    buffer: float
    action: str  # allow, reject_trade, reduce_size, manual_confirm_required
    reason: str


def check_execution_safety(
    bid: float,
    ask: float,
    mid_price: float,
    depth_score: float = 1.0,
    expected_slippage: float = 0.0,
    spread_buffer_coef: float = 1.0,
    slippage_buffer_coef: float = 1.0,
    liquidity_void_multiplier: float = 1.5,
    max_allowed_spread_pct: float = 0.003,
    min_depth_score: float = 0.4,
    action_on_wide_spread: str = "reject_trade",
    action_on_thin_depth: str = "manual_confirm_required",
) -> LiquidityCheckResult:
    if mid_price <= 0 or bid <= 0 or ask <= 0:
        return LiquidityCheckResult(
            safe=False, liquidity_state="unknown",
            spread_pct=0, depth_score=0, buffer=0,
            action="reject_trade", reason="invalid_price_data",
        )

    spread = ask - bid
    spread_pct = spread / mid_price

    buffer = (
        spread * spread_buffer_coef
        + expected_slippage * slippage_buffer_coef
    )

    if spread_pct > max_allowed_spread_pct:
        liquidity_state = "wide_spread"
        buffer *= liquidity_void_multiplier
        return LiquidityCheckResult(
            safe=False, liquidity_state=liquidity_state,
            spread_pct=spread_pct, depth_score=depth_score,
            buffer=buffer, action=action_on_wide_spread,
            reason=f"spread_{spread_pct:.4f}_exceeds_max_{max_allowed_spread_pct}",
        )

    if depth_score < min_depth_score:
        liquidity_state = "thin_depth"
        buffer *= liquidity_void_multiplier
        return LiquidityCheckResult(
            safe=False, liquidity_state=liquidity_state,
            spread_pct=spread_pct, depth_score=depth_score,
            buffer=buffer, action=action_on_thin_depth,
            reason=f"depth_{depth_score:.2f}_below_min_{min_depth_score}",
        )

    return LiquidityCheckResult(
        safe=True, liquidity_state="normal",
        spread_pct=spread_pct, depth_score=depth_score,
        buffer=buffer, action="allow",
        reason="liquidity_normal",
    )
