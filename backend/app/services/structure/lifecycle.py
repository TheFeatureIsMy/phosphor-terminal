from __future__ import annotations

from .models import (
    FairValueGap, OrderBlock, LiquidityPool,
    StructureStatus, PoolStatus, StructureDirection,
)
from .timeframe import can_invalidate_structure


def decay_strength(
    initial_strength: float,
    age_bars: int,
    touched_count: int,
    filled_ratio: float,
    low_tf_violation_count: int = 0,
) -> float:
    age_penalty = min(0.3, age_bars * 0.002)
    touch_penalty = min(0.4, touched_count * 0.10)
    fill_penalty = min(0.4, filled_ratio * 0.4)
    violation_penalty = min(0.2, low_tf_violation_count * 0.05)

    return max(
        0.0,
        initial_strength
        - age_penalty
        - touch_penalty
        - fill_penalty
        - violation_penalty,
    )


def update_fvg_lifecycle(
    fvg: FairValueGap,
    current_close: float,
    current_low: float,
    current_high: float,
    candle_tf: str,
    is_candle_close: bool = True,
) -> FairValueGap:
    if fvg.status in (StructureStatus.INVALIDATED, StructureStatus.EXPIRED):
        return fvg

    fvg.age_bars += 1

    if fvg.direction == StructureDirection.BULLISH:
        if current_low <= fvg.price_top and current_low >= fvg.price_bottom:
            fvg.status = StructureStatus.TOUCHED
            fvg.touched_count += 1
            gap_size = fvg.price_top - fvg.price_bottom
            if gap_size > 0:
                penetration = fvg.price_top - current_low
                fvg.filled_ratio = min(1.0, penetration / gap_size)

        if is_candle_close and can_invalidate_structure(candle_tf, fvg.timeframe):
            if current_close < fvg.price_bottom:
                fvg.status = StructureStatus.INVALIDATED
        elif current_close < fvg.price_bottom:
            fvg.low_tf_violation_count += 1

        if fvg.filled_ratio >= 0.9:
            fvg.status = StructureStatus.MITIGATED

    else:  # bearish
        if current_high >= fvg.price_bottom and current_high <= fvg.price_top:
            fvg.status = StructureStatus.TOUCHED
            fvg.touched_count += 1
            gap_size = fvg.price_top - fvg.price_bottom
            if gap_size > 0:
                penetration = current_high - fvg.price_bottom
                fvg.filled_ratio = min(1.0, penetration / gap_size)

        if is_candle_close and can_invalidate_structure(candle_tf, fvg.timeframe):
            if current_close > fvg.price_top:
                fvg.status = StructureStatus.INVALIDATED
        elif current_close > fvg.price_top:
            fvg.low_tf_violation_count += 1

        if fvg.filled_ratio >= 0.9:
            fvg.status = StructureStatus.MITIGATED

    fvg.current_strength = decay_strength(
        fvg.initial_strength, fvg.age_bars,
        fvg.touched_count, fvg.filled_ratio,
        fvg.low_tf_violation_count,
    )

    if fvg.current_strength <= 0.05:
        fvg.status = StructureStatus.EXPIRED

    return fvg


def update_ob_lifecycle(
    ob: OrderBlock,
    current_close: float,
    current_low: float,
    current_high: float,
    candle_tf: str,
    is_candle_close: bool = True,
) -> OrderBlock:
    if ob.status in (StructureStatus.INVALIDATED, StructureStatus.EXPIRED):
        return ob

    ob.age_bars += 1

    if ob.direction == StructureDirection.BULLISH:
        if current_low <= ob.price_top and current_low >= ob.price_bottom:
            if ob.status == StructureStatus.ACTIVE:
                ob.status = StructureStatus.TOUCHED
            ob.touched_count += 1

        if is_candle_close and can_invalidate_structure(candle_tf, ob.timeframe):
            if current_close < ob.price_bottom:
                ob.status = StructureStatus.INVALIDATED

        if ob.touched_count >= 3:
            ob.status = StructureStatus.MITIGATED

    else:  # bearish
        if current_high >= ob.price_bottom and current_high <= ob.price_top:
            if ob.status == StructureStatus.ACTIVE:
                ob.status = StructureStatus.TOUCHED
            ob.touched_count += 1

        if is_candle_close and can_invalidate_structure(candle_tf, ob.timeframe):
            if current_close > ob.price_top:
                ob.status = StructureStatus.INVALIDATED

        if ob.touched_count >= 3:
            ob.status = StructureStatus.MITIGATED

    ob.current_strength = decay_strength(
        ob.initial_strength, ob.age_bars, ob.touched_count, 0.0,
    )

    if ob.current_strength <= 0.05:
        ob.status = StructureStatus.EXPIRED

    return ob


def update_pool_lifecycle(
    pool: LiquidityPool,
    current_low: float,
    current_high: float,
) -> LiquidityPool:
    if pool.status in (PoolStatus.SWEPT, PoolStatus.INVALIDATED, PoolStatus.EXPIRED):
        return pool

    if pool.side == "sell_side":
        if current_low <= pool.price_level:
            pool.status = PoolStatus.TOUCHED
            pool.touched_count += 1
    else:
        if current_high >= pool.price_level:
            pool.status = PoolStatus.TOUCHED
            pool.touched_count += 1

    pool.current_strength = decay_strength(
        pool.initial_strength, 0, pool.touched_count, 0.0,
    )

    if pool.current_strength <= 0.05:
        pool.status = PoolStatus.EXPIRED

    return pool
