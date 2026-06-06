from __future__ import annotations

import pandas as pd
from .models import SwingPoint


def detect_swing_highs(df: pd.DataFrame, lookback: int = 5) -> list[SwingPoint]:
    highs = []
    high_col = df["high"].values
    n = len(high_col)
    for i in range(lookback, n - lookback):
        is_swing = True
        for j in range(1, lookback + 1):
            if high_col[i] <= high_col[i - j] or high_col[i] <= high_col[i + j]:
                is_swing = False
                break
        if is_swing:
            highs.append(SwingPoint(
                price=float(high_col[i]),
                index=i,
                is_high=True,
                strength=lookback,
            ))
    return highs


def detect_swing_lows(df: pd.DataFrame, lookback: int = 5) -> list[SwingPoint]:
    lows = []
    low_col = df["low"].values
    n = len(low_col)
    for i in range(lookback, n - lookback):
        is_swing = True
        for j in range(1, lookback + 1):
            if low_col[i] >= low_col[i - j] or low_col[i] >= low_col[i + j]:
                is_swing = False
                break
        if is_swing:
            lows.append(SwingPoint(
                price=float(low_col[i]),
                index=i,
                is_high=False,
                strength=lookback,
            ))
    return lows
