from __future__ import annotations

import uuid
import pandas as pd
from .models import FairValueGap, StructureDirection


def detect_fvg(df: pd.DataFrame, min_gap_atr_ratio: float = 0.3) -> list[FairValueGap]:
    fvgs = []
    highs = df["high"].values
    lows = df["low"].values
    n = len(df)

    atr_period = 14
    tr = pd.DataFrame({
        "hl": df["high"] - df["low"],
        "hc": abs(df["high"] - df["close"].shift(1)),
        "lc": abs(df["low"] - df["close"].shift(1)),
    }).max(axis=1)
    atr = tr.rolling(atr_period).mean()

    for i in range(2, n):
        atr_val = float(atr.iloc[i]) if i < len(atr) and not pd.isna(atr.iloc[i]) else 0.0

        # Bullish FVG: candle[i-2].high < candle[i].low (gap between candle before and after)
        if lows[i] > highs[i - 2]:
            gap_size = lows[i] - highs[i - 2]
            if atr_val > 0 and gap_size / atr_val < min_gap_atr_ratio:
                continue
            strength = min(1.0, 0.5 + gap_size / max(atr_val, 1.0) * 0.2)
            fvgs.append(FairValueGap(
                fvg_id=f"fvg_{uuid.uuid4().hex[:8]}",
                direction=StructureDirection.BULLISH,
                price_top=float(lows[i]),
                price_bottom=float(highs[i - 2]),
                initial_strength=strength,
                current_strength=strength,
                candle_index=i,
            ))

        # Bearish FVG: candle[i].high < candle[i-2].low
        if highs[i] < lows[i - 2]:
            gap_size = lows[i - 2] - highs[i]
            if atr_val > 0 and gap_size / atr_val < min_gap_atr_ratio:
                continue
            strength = min(1.0, 0.5 + gap_size / max(atr_val, 1.0) * 0.2)
            fvgs.append(FairValueGap(
                fvg_id=f"fvg_{uuid.uuid4().hex[:8]}",
                direction=StructureDirection.BEARISH,
                price_top=float(lows[i - 2]),
                price_bottom=float(highs[i]),
                initial_strength=strength,
                current_strength=strength,
                candle_index=i,
            ))

    return fvgs
