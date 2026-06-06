from __future__ import annotations

import uuid
import numpy as np
import pandas as pd
from .models import LiquidityPool, LiquiditySweep, SweepState, PoolStatus


def detect_sell_side_sweeps(
    df: pd.DataFrame,
    pools: list[LiquidityPool],
    atr: pd.Series,
    volume_zscore: pd.Series,
    max_sweep_depth_atr: float = 3.0,
    min_volume_zscore: float = 1.5,
    reclaim_window: int = 5,
) -> list[LiquiditySweep]:
    sweeps = []
    lows = df["low"].values
    closes = df["close"].values
    n = len(df)

    sell_pools = [p for p in pools if p.side == "sell_side" and p.status == PoolStatus.ACTIVE]

    for pool in sell_pools:
        for i in range(max(1, n - 20), n):
            if lows[i] >= pool.price_level:
                continue

            sweep_depth = pool.price_level - lows[i]
            atr_val = float(atr.iloc[i]) if i < len(atr) and atr.iloc[i] > 0 else 1.0

            if sweep_depth > max_sweep_depth_atr * atr_val:
                continue

            vol_z = float(volume_zscore.iloc[i]) if i < len(volume_zscore) else 0.0

            sweep = LiquiditySweep(
                sweep_id=f"sw_{uuid.uuid4().hex[:8]}",
                pool=pool,
                state=SweepState.SWEEP_CANDIDATE,
                sweep_type="sell_side_liquidity_sweep",
                swept_level=pool.price_level,
                sweep_low=float(lows[i]),
                volume_zscore=vol_z,
                candle_index=i,
            )

            reclaim_end = min(i + reclaim_window + 1, n)
            for j in range(i, reclaim_end):
                if closes[j] > pool.price_level:
                    sweep.state = SweepState.CONFIRMED_SWEEP
                    sweep.reclaim_price = float(closes[j])
                    sweep.confidence = _calc_sweep_confidence(
                        vol_z, sweep_depth, atr_val, min_volume_zscore
                    )
                    pool.status = PoolStatus.SWEPT
                    break

            if sweep.state == SweepState.SWEEP_CANDIDATE and closes[min(i, n-1)] > pool.price_level:
                sweep.state = SweepState.RECLAIM_PENDING

            if sweep.state != SweepState.NONE:
                sweeps.append(sweep)

    return sweeps


def detect_buy_side_sweeps(
    df: pd.DataFrame,
    pools: list[LiquidityPool],
    atr: pd.Series,
    volume_zscore: pd.Series,
    max_sweep_depth_atr: float = 3.0,
    min_volume_zscore: float = 1.5,
    reclaim_window: int = 5,
) -> list[LiquiditySweep]:
    sweeps = []
    highs = df["high"].values
    closes = df["close"].values
    n = len(df)

    buy_pools = [p for p in pools if p.side == "buy_side" and p.status == PoolStatus.ACTIVE]

    for pool in buy_pools:
        for i in range(max(1, n - 20), n):
            if highs[i] <= pool.price_level:
                continue

            sweep_depth = highs[i] - pool.price_level
            atr_val = float(atr.iloc[i]) if i < len(atr) and atr.iloc[i] > 0 else 1.0

            if sweep_depth > max_sweep_depth_atr * atr_val:
                continue

            vol_z = float(volume_zscore.iloc[i]) if i < len(volume_zscore) else 0.0

            sweep = LiquiditySweep(
                sweep_id=f"sw_{uuid.uuid4().hex[:8]}",
                pool=pool,
                state=SweepState.SWEEP_CANDIDATE,
                sweep_type="buy_side_liquidity_sweep",
                swept_level=pool.price_level,
                sweep_high=float(highs[i]),
                volume_zscore=vol_z,
                candle_index=i,
            )

            reclaim_end = min(i + reclaim_window + 1, n)
            for j in range(i, reclaim_end):
                if closes[j] < pool.price_level:
                    sweep.state = SweepState.CONFIRMED_SWEEP
                    sweep.reclaim_price = float(closes[j])
                    sweep.confidence = _calc_sweep_confidence(
                        vol_z, sweep_depth, atr_val, min_volume_zscore
                    )
                    pool.status = PoolStatus.SWEPT
                    break

            if sweep.state != SweepState.NONE:
                sweeps.append(sweep)

    return sweeps


def _calc_sweep_confidence(vol_z: float, depth: float, atr: float, min_vol_z: float) -> float:
    vol_score = min(1.0, max(0.0, vol_z / max(min_vol_z * 2, 1.0)))
    depth_score = max(0.0, 1.0 - depth / (atr * 3)) if atr > 0 else 0.5
    return round(vol_score * 0.5 + depth_score * 0.5, 3)
