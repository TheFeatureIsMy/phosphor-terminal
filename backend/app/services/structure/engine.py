from __future__ import annotations

import logging
import numpy as np
import pandas as pd

from .models import (
    StructureSnapshot, StructureDirection, MarketRegime,
    LiquidityPool, FairValueGap, OrderBlock, PoolStatus, StructureStatus,
)
from .swing import detect_swing_highs, detect_swing_lows
from .liquidity_pool import detect_equal_levels, detect_swing_pools
from .liquidity_sweep import detect_sell_side_sweeps, detect_buy_side_sweeps
from .fvg import detect_fvg
from .order_block import detect_order_blocks
from .bos_choch import detect_bos_choch
from .market_regime import classify_regime
from .lifecycle import update_fvg_lifecycle, update_ob_lifecycle, update_pool_lifecycle
from .entry_score import calculate_entry_score
from .stop_calculator import calculate_structure_stop

logger = logging.getLogger(__name__)


class StructureEngine:
    def __init__(self, timeframe: str = "5m", swing_lookback: int = 5):
        self._timeframe = timeframe
        self._swing_lookback = swing_lookback
        self._prev_pools: list[LiquidityPool] = []
        self._prev_fvgs: list[FairValueGap] = []
        self._prev_obs: list[OrderBlock] = []

    def analyze(self, df: pd.DataFrame) -> StructureSnapshot:
        if len(df) < self._swing_lookback * 2 + 5:
            return StructureSnapshot()

        try:
            regime = classify_regime(df)
            swing_highs = detect_swing_highs(df, lookback=self._swing_lookback)
            swing_lows = detect_swing_lows(df, lookback=self._swing_lookback)

            # Detect liquidity pools
            equal_high_pools = detect_equal_levels(swing_highs, tolerance_pct=0.001)
            equal_low_pools = detect_equal_levels(swing_lows, tolerance_pct=0.001)
            swing_pools = detect_swing_pools(swing_highs, swing_lows)
            all_pools = self._prev_pools + equal_high_pools + equal_low_pools + swing_pools
            # Deduplicate by removing expired/invalidated
            all_pools = [p for p in all_pools if p.status in (PoolStatus.ACTIVE, PoolStatus.TOUCHED)]

            # Compute ATR and volume z-score for sweep detection
            atr = self._compute_atr(df)
            vol_zscore = self._compute_volume_zscore(df)

            # Detect sweeps
            sell_sweeps = detect_sell_side_sweeps(df, all_pools, atr, vol_zscore)
            buy_sweeps = detect_buy_side_sweeps(df, all_pools, atr, vol_zscore)
            all_sweeps = sell_sweeps + buy_sweeps

            # Detect FVG and Order Blocks
            new_fvgs = detect_fvg(df)
            new_obs = detect_order_blocks(df)

            # Update lifecycle for existing structures
            last_close = float(df["close"].iloc[-1])
            last_low = float(df["low"].iloc[-1])
            last_high = float(df["high"].iloc[-1])

            active_fvgs = []
            for fvg in self._prev_fvgs + new_fvgs:
                fvg = update_fvg_lifecycle(
                    fvg, last_close, last_low, last_high,
                    self._timeframe, is_candle_close=True,
                )
                if fvg.status not in (StructureStatus.INVALIDATED, StructureStatus.EXPIRED):
                    active_fvgs.append(fvg)

            active_obs = []
            for ob in self._prev_obs + new_obs:
                ob = update_ob_lifecycle(
                    ob, last_close, last_low, last_high,
                    self._timeframe, is_candle_close=True,
                )
                if ob.status not in (StructureStatus.INVALIDATED, StructureStatus.EXPIRED):
                    active_obs.append(ob)

            for pool in all_pools:
                update_pool_lifecycle(pool, last_low, last_high)

            active_pools = [p for p in all_pools if p.status in (PoolStatus.ACTIVE, PoolStatus.TOUCHED)]

            # Detect BOS/CHoCH
            closes_list = df["close"].tolist()
            breaks = detect_bos_choch(swing_highs, swing_lows, closes_list)

            # Determine structure direction from recent breaks
            direction = None
            if breaks:
                last_break = breaks[-1]
                direction = last_break.direction

            # Calculate entry score
            score, reasons = calculate_entry_score(
                direction=direction or StructureDirection.BULLISH,
                sweeps=all_sweeps,
                fvgs=active_fvgs,
                order_blocks=active_obs,
                structure_breaks=breaks,
                regime=regime,
                volume_confirmed=self._check_volume(df),
            )

            # Cache state for next call
            self._prev_pools = active_pools
            self._prev_fvgs = active_fvgs
            self._prev_obs = active_obs

            return StructureSnapshot(
                market_regime=regime,
                swing_highs=swing_highs,
                swing_lows=swing_lows,
                liquidity_pools=active_pools,
                active_sweeps=all_sweeps,
                fvg_zones=active_fvgs,
                order_blocks=active_obs,
                structure_breaks=breaks,
                structure_score=score,
                structure_direction=direction,
            )

        except Exception:
            logger.exception("structure analysis failed")
            return StructureSnapshot()

    def _compute_atr(self, df: pd.DataFrame, period: int = 14) -> pd.Series:
        tr = pd.DataFrame({
            "hl": df["high"] - df["low"],
            "hc": abs(df["high"] - df["close"].shift(1)),
            "lc": abs(df["low"] - df["close"].shift(1)),
        }).max(axis=1)
        return tr.rolling(period).mean().fillna(tr)

    def _compute_volume_zscore(self, df: pd.DataFrame, period: int = 20) -> pd.Series:
        vol = df["volume"]
        mean = vol.rolling(period).mean()
        std = vol.rolling(period).std()
        zscore = (vol - mean) / std.replace(0, 1)
        return zscore.fillna(0)

    def _check_volume(self, df: pd.DataFrame) -> bool:
        if len(df) < 2:
            return False
        last_vol = df["volume"].iloc[-1]
        avg_vol = df["volume"].tail(20).mean()
        return last_vol > avg_vol * 1.5 if avg_vol > 0 else False
