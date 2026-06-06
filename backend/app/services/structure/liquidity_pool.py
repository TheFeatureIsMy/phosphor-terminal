from __future__ import annotations

import uuid
from .models import LiquidityPool, SwingPoint


def detect_equal_levels(
    swings: list[SwingPoint],
    tolerance_pct: float = 0.001,
    min_count: int = 2,
) -> list[LiquidityPool]:
    if len(swings) < min_count:
        return []

    pools = []
    used = set()

    for i, s1 in enumerate(swings):
        if i in used:
            continue
        cluster = [s1]
        for j, s2 in enumerate(swings):
            if j <= i or j in used:
                continue
            if abs(s1.price - s2.price) / s1.price <= tolerance_pct:
                cluster.append(s2)
                used.add(j)

        if len(cluster) >= min_count:
            used.add(i)
            avg_price = sum(s.price for s in cluster) / len(cluster)
            side = "buy_side" if s1.is_high else "sell_side"
            pool_type = "equal_high" if s1.is_high else "equal_low"
            strength = min(1.0, 0.5 + len(cluster) * 0.15)

            pools.append(LiquidityPool(
                pool_id=f"lp_{uuid.uuid4().hex[:8]}",
                pool_type=pool_type,
                side=side,
                price_level=avg_price,
                initial_strength=strength,
                current_strength=strength,
            ))

    return pools


def detect_swing_pools(
    swing_highs: list[SwingPoint],
    swing_lows: list[SwingPoint],
) -> list[LiquidityPool]:
    pools = []

    for sh in swing_highs:
        pools.append(LiquidityPool(
            pool_id=f"lp_{uuid.uuid4().hex[:8]}",
            pool_type="swing_high",
            side="buy_side",
            price_level=sh.price,
            initial_strength=0.6 + min(0.3, sh.strength * 0.05),
            current_strength=0.6 + min(0.3, sh.strength * 0.05),
        ))

    for sl in swing_lows:
        pools.append(LiquidityPool(
            pool_id=f"lp_{uuid.uuid4().hex[:8]}",
            pool_type="swing_low",
            side="sell_side",
            price_level=sl.price,
            initial_strength=0.6 + min(0.3, sl.strength * 0.05),
            current_strength=0.6 + min(0.3, sl.strength * 0.05),
        ))

    return pools
