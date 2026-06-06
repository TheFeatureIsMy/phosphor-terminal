from __future__ import annotations

from .models import (
    LiquiditySweep, FairValueGap, OrderBlock, StructureBreak,
    SweepState, StructureStatus, StructureDirection, MarketRegime,
)


SCORE_WEIGHTS = {
    "sweep_confirmed": 25,
    "reclaim_confirmed": 15,
    "fvg_ob_active": 20,
    "higher_tf_aligned": 15,
    "volume_confirmed": 10,
    "regime_allowed": 10,
    "ai_risk_low": 5,
}

BLOCKED_REGIMES = {MarketRegime.PANIC, MarketRegime.NEWS_SHOCK, MarketRegime.LIQUIDITY_VOID}


def calculate_entry_score(
    direction: StructureDirection,
    sweeps: list[LiquiditySweep],
    fvgs: list[FairValueGap],
    order_blocks: list[OrderBlock],
    structure_breaks: list[StructureBreak],
    regime: MarketRegime,
    higher_tf_direction: StructureDirection | None = None,
    volume_confirmed: bool = False,
    ai_risk_score: float = 0.0,
) -> tuple[int, list[str]]:
    score = 0
    reasons = []

    if regime in BLOCKED_REGIMES:
        return 0, ["regime_blocked"]

    # Sweep confirmed
    confirmed = [s for s in sweeps if s.state == SweepState.CONFIRMED_SWEEP]
    if direction == StructureDirection.BULLISH:
        sell_sweeps = [s for s in confirmed if s.sweep_type == "sell_side_liquidity_sweep"]
        if sell_sweeps:
            score += SCORE_WEIGHTS["sweep_confirmed"]
            reasons.append("sell_side_sweep_confirmed")
            if any(s.reclaim_price > 0 for s in sell_sweeps):
                score += SCORE_WEIGHTS["reclaim_confirmed"]
                reasons.append("reclaim_confirmed")
    else:
        buy_sweeps = [s for s in confirmed if s.sweep_type == "buy_side_liquidity_sweep"]
        if buy_sweeps:
            score += SCORE_WEIGHTS["sweep_confirmed"]
            reasons.append("buy_side_sweep_confirmed")
            if any(s.reclaim_price > 0 for s in buy_sweeps):
                score += SCORE_WEIGHTS["reclaim_confirmed"]
                reasons.append("reclaim_confirmed")

    # FVG / OB active
    active_fvgs = [f for f in fvgs if f.status == StructureStatus.ACTIVE and f.direction == direction]
    active_obs = [o for o in order_blocks if o.status == StructureStatus.ACTIVE and o.direction == direction]
    if active_fvgs or active_obs:
        score += SCORE_WEIGHTS["fvg_ob_active"]
        if active_fvgs:
            reasons.append("bullish_fvg_active" if direction == StructureDirection.BULLISH else "bearish_fvg_active")
        if active_obs:
            reasons.append("order_block_active")

    # Higher TF alignment
    if higher_tf_direction is not None:
        if higher_tf_direction == direction:
            score += SCORE_WEIGHTS["higher_tf_aligned"]
            reasons.append("higher_timeframe_aligned")
        elif higher_tf_direction != direction:
            reasons.append("higher_timeframe_conflicting")

    # Volume
    if volume_confirmed:
        score += SCORE_WEIGHTS["volume_confirmed"]
        reasons.append("volume_confirmed")

    # Regime
    if regime not in BLOCKED_REGIMES:
        score += SCORE_WEIGHTS["regime_allowed"]
        reasons.append("regime_allowed")

    # AI risk
    if ai_risk_score <= 0.65:
        score += SCORE_WEIGHTS["ai_risk_low"]
        reasons.append("ai_risk_acceptable")

    return min(score, 100), reasons
