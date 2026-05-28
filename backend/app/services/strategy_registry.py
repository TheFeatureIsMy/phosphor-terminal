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
    return STRATEGY_DIR / f"{class_name}.py"


def render_freqtrade_strategy(class_name: str, strategy_type: str, parameters: dict[str, Any]) -> str:
    fast_period = int(parameters.get("fast_period") or parameters.get("short_window") or 20)
    slow_period = int(parameters.get("slow_period") or parameters.get("long_window") or 50)
    rsi_period = int(parameters.get("rsi_period") or 14)
    stoploss = float(parameters.get("stoploss") or -0.05)
    roi = float(parameters.get("minimal_roi") or 0.1)

    if slow_period <= fast_period:
        slow_period = fast_period + 10

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


def register_strategy_file(strategy_id: int, name: str, strategy_type: str, parameters: dict[str, Any]) -> str:
    class_name = strategy_class_name(strategy_id, name)
    STRATEGY_DIR.mkdir(parents=True, exist_ok=True)
    strategy_file_path(class_name).write_text(
        render_freqtrade_strategy(class_name, strategy_type, parameters),
        encoding="utf-8",
    )
    return class_name
