from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from app.config import PROJECT_ROOT


STRATEGY_DIR = Path(PROJECT_ROOT) / "freqtrade" / "user_data" / "strategies"


def strategy_class_name(strategy_id: int, name: str) -> str:
    slug = re.sub(r"[^0-9A-Za-z]+", " ", name).title().replace(" ", "")
    if not slug:
        slug = "Strategy"
    if slug[0].isdigit():
        slug = f"S{slug}"
    return f"PulseDesk{strategy_id}{slug}"


def strategy_file_path(class_name: str) -> Path:
    target = (STRATEGY_DIR / f"{class_name}.py").resolve()
    if not str(target).startswith(str(STRATEGY_DIR.resolve())):
        raise ValueError(f"Path traversal detected: {class_name}")
    return target


def render_freqtrade_strategy(class_name: str, strategy_type: str, parameters: dict[str, Any]) -> str:
    fast_period = int(parameters.get("fast_period") or parameters.get("short_window") or 20)
    slow_period = int(parameters.get("slow_period") or parameters.get("long_window") or 50)
    rsi_period = int(parameters.get("rsi_period") or 14)
    stoploss = float(parameters.get("stoploss") or -0.05)
    roi = float(parameters.get("minimal_roi") or 0.1)
    lookback = int(parameters.get("lookback_period") or 20)
    breakout_threshold = float(parameters.get("breakout_threshold") or 0.02)

    if slow_period <= fast_period:
        slow_period = fast_period + 10

    if strategy_type == "breakout":
        return _render_breakout(class_name, parameters, lookback, breakout_threshold, stoploss, roi)
    elif strategy_type == "mean_reversion":
        return _render_mean_reversion(class_name, parameters, rsi_period, stoploss, roi)
    elif strategy_type == "grid":
        return _render_grid(class_name, parameters, stoploss, roi)
    return _render_ma_cross(class_name, parameters, fast_period, slow_period, rsi_period, stoploss, roi)


def _render_ma_cross(class_name: str, parameters: dict, fast_period: int, slow_period: int, rsi_period: int, stoploss: float, roi: float) -> str:
    return f'''from freqtrade.strategy import IStrategy
from pandas import DataFrame
import talib.abstract as ta


class {class_name}(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    can_short = False
    minimal_roi = {{"0": {roi}}}
    stoploss = {stoploss}

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe["rsi"] = ta.RSI(dataframe, timeperiod={rsi_period})
        dataframe["sma_fast"] = ta.SMA(dataframe, timeperiod={fast_period})
        dataframe["sma_slow"] = ta.SMA(dataframe, timeperiod={slow_period})
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["sma_fast"] > dataframe["sma_slow"]) & (dataframe["rsi"] < 70),
            "enter_long",
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["sma_fast"] < dataframe["sma_slow"]) | (dataframe["rsi"] > 75),
            "exit_long",
        ] = 1
        return dataframe
'''


def _render_breakout(class_name: str, parameters: dict, lookback: int, threshold: float, stoploss: float, roi: float) -> str:
    return f'''from freqtrade.strategy import IStrategy
from pandas import DataFrame
import talib.abstract as ta


class {class_name}(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    can_short = False
    minimal_roi = {{"0": {roi}}}
    stoploss = {stoploss}

    lookback_period = {lookback}
    breakout_threshold = {threshold}

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe["high_n"] = dataframe["high"].rolling(self.lookback_period).max()
        dataframe["low_n"] = dataframe["low"].rolling(self.lookback_period).min()
        dataframe["atr"] = ta.ATR(dataframe, timeperiod=14)
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["close"] > dataframe["high_n"].shift(1) * (1 + self.breakout_threshold)),
            "enter_long",
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["close"] < dataframe["low_n"].shift(1) * (1 - self.breakout_threshold)),
            "exit_long",
        ] = 1
        return dataframe
'''


def _render_mean_reversion(class_name: str, parameters: dict, rsi_period: int, stoploss: float, roi: float) -> str:
    z_threshold = float(parameters.get("z_score_threshold") or 2.0)
    return f'''from freqtrade.strategy import IStrategy
from pandas import DataFrame
import talib.abstract as ta
import numpy as np


class {class_name}(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    can_short = False
    minimal_roi = {{"0": {roi}}}
    stoploss = {stoploss}

    z_score_threshold = {z_threshold}
    lookback_period = 50

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe["sma"] = ta.SMA(dataframe, timeperiod=self.lookback_period)
        dataframe["std"] = dataframe["close"].rolling(self.lookback_period).std()
        dataframe["z_score"] = (dataframe["close"] - dataframe["sma"]) / dataframe["std"].replace(0, np.nan)
        dataframe["rsi"] = ta.RSI(dataframe, timeperiod={rsi_period})
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["z_score"] < -self.z_score_threshold) & (dataframe["rsi"] < 35),
            "enter_long",
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["z_score"] > 0.5) | (dataframe["rsi"] > 70),
            "exit_long",
        ] = 1
        return dataframe
'''


def _render_grid(class_name: str, parameters: dict, stoploss: float, roi: float) -> str:
    grid_spacing = float(parameters.get("grid_spacing") or 0.01)
    grid_levels = int(parameters.get("grid_levels") or 10)
    return f'''from freqtrade.strategy import IStrategy
from pandas import DataFrame
import talib.abstract as ta


class {class_name}(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    can_short = False
    minimal_roi = {{"0": {roi}}}
    stoploss = {stoploss}

    grid_spacing = {grid_spacing}
    grid_levels = {grid_levels}

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe["sma_50"] = ta.SMA(dataframe, timeperiod=50)
        dataframe["atr"] = ta.ATR(dataframe, timeperiod=14)
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["close"] < dataframe["sma_50"] * (1 - self.grid_spacing)),
            "enter_long",
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["close"] > dataframe["sma_50"] * (1 + self.grid_spacing)),
            "exit_long",
        ] = 1
        return dataframe
'''


def register_strategy_file(strategy_id: int, name: str, strategy_type: str, parameters: dict[str, Any]) -> str:
    class_name = strategy_class_name(strategy_id, name)
    STRATEGY_DIR.mkdir(parents=True, exist_ok=True)
    strategy_file_path(class_name).write_text(
        render_freqtrade_strategy(class_name, strategy_type, parameters),
        encoding="utf-8",
    )
    return class_name


def delete_strategy_file(class_name: str) -> None:
    try:
        path = strategy_file_path(class_name)
        if path.exists():
            path.unlink()
    except (ValueError, OSError):
        pass
