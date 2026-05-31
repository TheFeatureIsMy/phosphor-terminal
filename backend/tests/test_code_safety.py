from app.services.code_safety import scan_strategy_code


def test_clean_strategy_passes():
    code = """
from freqtrade.strategy import IStrategy
from pandas import DataFrame
import talib.abstract as ta

class TestStrategy(IStrategy):
    INTERFACE_VERSION = 3
    def populate_indicators(self, dataframe, metadata):
        return dataframe
"""
    result = scan_strategy_code(code)
    assert result["status"] == "passed"
    assert len(result["findings"]) == 0


def test_blocked_import_detected():
    code = """
import os
class Test(IStrategy):
    pass
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"
    assert any("os" in f["message"] for f in result["findings"])


def test_blocked_subprocess_import_detected():
    code = """
import subprocess
class Test(IStrategy):
    pass
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"


def test_blocked_socket_import_detected():
    code = """
import socket
class Test(IStrategy):
    pass
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"


def test_blocked_from_import_detected():
    code = """
from os import path
class Test(IStrategy):
    pass
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"


def test_blocked_eval_call_detected():
    code = """
class Test(IStrategy):
    def run(self):
        eval("print(1)")
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"


def test_blocked_exec_call_detected():
    code = """
class Test(IStrategy):
    def run(self):
        exec("x = 1")
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"


def test_blocked_open_call_detected():
    code = """
class Test(IStrategy):
    def run(self):
        open("file.txt")
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"


def test_blocked_compile_call_detected():
    code = """
class Test(IStrategy):
    def run(self):
        compile("x = 1", "", "exec")
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"


def test_syntax_error_detected():
    code = """
class Test(IStrategy):
    def broken( self
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"


def test_import_from_shutil_detected():
    code = """
from shutil import rmtree
class Test(IStrategy):
    pass
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"


def test_multiple_blocked_imports():
    code = """
import os
import socket
class Test(IStrategy):
    pass
"""
    result = scan_strategy_code(code)
    assert result["status"] == "failed"
    assert len(result["findings"]) >= 2


def test_legitimate_freqtrade_imports_pass():
    code = """
from freqtrade.strategy import IStrategy, merge_informative_pair
from pandas import DataFrame
import talib.abstract as ta
import numpy as np

class MyStrategy(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    def populate_indicators(self, dataframe, metadata):
        dataframe["rsi"] = ta.RSI(dataframe, timeperiod=14)
        return dataframe
    def populate_entry_trend(self, dataframe, metadata):
        return dataframe
    def populate_exit_trend(self, dataframe, metadata):
        return dataframe
"""
    result = scan_strategy_code(code)
    assert result["status"] == "passed"
