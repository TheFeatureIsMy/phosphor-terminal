from __future__ import annotations

import numpy as np
import pandas as pd
from .models import MarketRegime


def classify_regime(
    df: pd.DataFrame,
    atr_period: int = 14,
    ema_short: int = 20,
    ema_long: int = 50,
    volatility_threshold: float = 2.0,
) -> MarketRegime:
    if len(df) < max(atr_period, ema_long) + 5:
        return MarketRegime.UNKNOWN

    close = df["close"]

    ema_s = close.ewm(span=ema_short, adjust=False).mean()
    ema_l = close.ewm(span=ema_long, adjust=False).mean()

    tr = pd.DataFrame({
        "hl": df["high"] - df["low"],
        "hc": abs(df["high"] - close.shift(1)),
        "lc": abs(df["low"] - close.shift(1)),
    }).max(axis=1)
    atr = tr.rolling(atr_period).mean()
    atr_pct = (atr / close * 100).iloc[-1]

    last_ema_s = ema_s.iloc[-1]
    last_ema_l = ema_l.iloc[-1]
    last_close = close.iloc[-1]

    recent_returns = close.pct_change().tail(5)
    max_drop = recent_returns.min()

    if max_drop < -0.05:
        return MarketRegime.PANIC

    if atr_pct > volatility_threshold * 1.5:
        return MarketRegime.HIGH_VOLATILITY

    if last_ema_s > last_ema_l * 1.005 and last_close > last_ema_s:
        return MarketRegime.TREND_UP

    if last_ema_s < last_ema_l * 0.995 and last_close < last_ema_s:
        return MarketRegime.TREND_DOWN

    return MarketRegime.RANGE
