from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from .models import (
    LiquiditySweep, FairValueGap, OrderBlock,
    StructureDirection, StructureStatus, SweepState,
)


@dataclass
class StopResult:
    stop_price: float
    stop_type: str
    basis: str
    distance_pct: float
    atr_buffer: float = 0.0
    spread_buffer: float = 0.0
    slippage_buffer: float = 0.0


def calculate_structure_stop(
    direction: StructureDirection,
    entry_price: float,
    sweeps: list[LiquiditySweep],
    fvgs: list[FairValueGap],
    order_blocks: list[OrderBlock],
    atr: float,
    atr_buffer_coef: float = 0.3,
    spread: float = 0.0,
    spread_buffer_coef: float = 1.0,
    slippage: float = 0.0,
    slippage_buffer_coef: float = 1.0,
    fallback_stop_pct: float = 0.02,
    max_stop_distance_pct: float = 0.03,
) -> StopResult:
    atr_buffer = atr * atr_buffer_coef
    spread_buffer = spread * spread_buffer_coef
    slippage_buffer = slippage * slippage_buffer_coef
    total_buffer = atr_buffer + spread_buffer + slippage_buffer

    candidates: list[tuple[float, str, str]] = []

    if direction == StructureDirection.BULLISH:
        # Sweep low
        confirmed = [s for s in sweeps
                     if s.state == SweepState.CONFIRMED_SWEEP
                     and s.sweep_type == "sell_side_liquidity_sweep"]
        for s in confirmed:
            raw = s.sweep_low - total_buffer
            candidates.append((raw, "structure_invalidated", f"below_sweep_low_{s.sweep_low}"))

        # OB low
        active_obs = [o for o in order_blocks
                      if o.direction == StructureDirection.BULLISH
                      and o.status in (StructureStatus.ACTIVE, StructureStatus.TOUCHED)]
        for ob in active_obs:
            raw = ob.price_bottom - total_buffer
            candidates.append((raw, "structure_invalidated", f"below_ob_low_{ob.price_bottom}"))

        # FVG low
        active_fvgs = [f for f in fvgs
                       if f.direction == StructureDirection.BULLISH
                       and f.status in (StructureStatus.ACTIVE, StructureStatus.TOUCHED)]
        for fvg in active_fvgs:
            raw = fvg.price_bottom - total_buffer
            candidates.append((raw, "structure_invalidated", f"below_fvg_low_{fvg.price_bottom}"))

        # Fallback
        fallback = entry_price * (1 - fallback_stop_pct) - total_buffer
        candidates.append((fallback, "fallback_fixed_pct", "static_fallback"))

        # Pick highest stop (closest to entry = tightest)
        candidates.sort(key=lambda x: x[0], reverse=True)

    else:  # BEARISH
        confirmed = [s for s in sweeps
                     if s.state == SweepState.CONFIRMED_SWEEP
                     and s.sweep_type == "buy_side_liquidity_sweep"]
        for s in confirmed:
            raw = s.sweep_high + total_buffer
            candidates.append((raw, "structure_invalidated", f"above_sweep_high_{s.sweep_high}"))

        active_obs = [o for o in order_blocks
                      if o.direction == StructureDirection.BEARISH
                      and o.status in (StructureStatus.ACTIVE, StructureStatus.TOUCHED)]
        for ob in active_obs:
            raw = ob.price_top + total_buffer
            candidates.append((raw, "structure_invalidated", f"above_ob_top_{ob.price_top}"))

        active_fvgs = [f for f in fvgs
                       if f.direction == StructureDirection.BEARISH
                       and f.status in (StructureStatus.ACTIVE, StructureStatus.TOUCHED)]
        for fvg in active_fvgs:
            raw = fvg.price_top + total_buffer
            candidates.append((raw, "structure_invalidated", f"above_fvg_top_{fvg.price_top}"))

        fallback = entry_price * (1 + fallback_stop_pct) + total_buffer
        candidates.append((fallback, "fallback_fixed_pct", "static_fallback"))

        # Pick lowest stop (closest to entry = tightest)
        candidates.sort(key=lambda x: x[0])

    if not candidates:
        stop_price = entry_price * (1 - fallback_stop_pct) if direction == StructureDirection.BULLISH else entry_price * (1 + fallback_stop_pct)
        return StopResult(
            stop_price=stop_price, stop_type="fallback_fixed_pct",
            basis="no_structure_available",
            distance_pct=fallback_stop_pct,
        )

    best = candidates[0]
    distance = abs(entry_price - best[0]) / entry_price if entry_price > 0 else 0

    if distance > max_stop_distance_pct:
        stop_price = entry_price * (1 - max_stop_distance_pct) if direction == StructureDirection.BULLISH else entry_price * (1 + max_stop_distance_pct)
        return StopResult(
            stop_price=stop_price, stop_type="clamped_max_distance",
            basis=f"original_{best[2]}_clamped",
            distance_pct=max_stop_distance_pct,
            atr_buffer=atr_buffer, spread_buffer=spread_buffer, slippage_buffer=slippage_buffer,
        )

    return StopResult(
        stop_price=best[0], stop_type=best[1], basis=best[2],
        distance_pct=distance,
        atr_buffer=atr_buffer, spread_buffer=spread_buffer, slippage_buffer=slippage_buffer,
    )
