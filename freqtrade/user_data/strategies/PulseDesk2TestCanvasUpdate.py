from freqtrade.strategy import IStrategy
from pandas import DataFrame
import talib.abstract as ta


class PulseDesk2TestCanvasUpdate(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    can_short = False
    minimal_roi = {"0": 0.1}
    stoploss = -0.05

    grid_spacing = 0.01
    grid_levels = 10

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
