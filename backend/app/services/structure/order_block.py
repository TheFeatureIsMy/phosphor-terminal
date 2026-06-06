from __future__ import annotations

import uuid
import numpy as np
import pandas as pd
from .models import OrderBlock, StructureDirection


def detect_order_blocks(
    df: pd.DataFrame,
    volume_threshold: float = 1.5,
    lookback: int = 3,
) -> list[OrderBlock]:
    obs = []
    opens = df["open"].values
    closes = df["close"].values
    highs = df["high"].values
    lows = df["low"].values
    volumes = df["volume"].values
    n = len(df)

    vol_mean = np.mean(volumes[max(0, n-50):n]) if n > 0 else 1.0

    for i in range(lookback, n - 1):
        vol_ratio = volumes[i] / vol_mean if vol_mean > 0 else 1.0
        if vol_ratio < volume_threshold:
            continue

        is_bearish_candle = closes[i] < opens[i]
        is_bullish_candle = closes[i] > opens[i]

        # Bullish OB: bearish candle followed by strong bullish move
        if is_bearish_candle:
            future_bullish = False
            for j in range(i + 1, min(i + lookback + 1, n)):
                if closes[j] > highs[i]:
                    future_bullish = True
                    break
            if future_bullish:
                strength = min(1.0, 0.5 + vol_ratio * 0.1)
                obs.append(OrderBlock(
                    ob_id=f"ob_{uuid.uuid4().hex[:8]}",
                    direction=StructureDirection.BULLISH,
                    price_top=float(highs[i]),
                    price_bottom=float(lows[i]),
                    initial_strength=strength,
                    current_strength=strength,
                    candle_index=i,
                    volume_ratio=vol_ratio,
                ))

        # Bearish OB: bullish candle followed by strong bearish move
        if is_bullish_candle:
            future_bearish = False
            for j in range(i + 1, min(i + lookback + 1, n)):
                if closes[j] < lows[i]:
                    future_bearish = True
                    break
            if future_bearish:
                strength = min(1.0, 0.5 + vol_ratio * 0.1)
                obs.append(OrderBlock(
                    ob_id=f"ob_{uuid.uuid4().hex[:8]}",
                    direction=StructureDirection.BEARISH,
                    price_top=float(highs[i]),
                    price_bottom=float(lows[i]),
                    initial_strength=strength,
                    current_strength=strength,
                    candle_index=i,
                    volume_ratio=vol_ratio,
                ))

    return obs
