"""Tests for PulseDeskUniversalStrategy — caching, safe hold, fail closed."""
import json
import os
import sys
import tempfile
import time
from pathlib import Path
from unittest.mock import MagicMock, patch

import numpy as np
import pandas as pd
import pytest

BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

STRATEGY_DIR = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..", "freqtrade", "user_data", "strategies"
))
if STRATEGY_DIR not in sys.path:
    sys.path.insert(0, STRATEGY_DIR)

sys.modules.setdefault("freqtrade", MagicMock())
sys.modules.setdefault("freqtrade.strategy", MagicMock())
sys.modules.setdefault("freqtrade.strategy.interface", MagicMock())

_mock_istrategy = type("IStrategy", (), {
    "INTERFACE_VERSION": 3,
    "timeframe": "5m",
    "stoploss": -0.10,
    "trailing_stop": False,
    "trailing_stop_positive": None,
    "trailing_stop_positive_offset": 0.0,
    "minimal_roi": {"0": 100},
    "process_only_new_candles": True,
    "startup_candle_count": 50,
})
sys.modules["freqtrade.strategy.interface"].IStrategy = _mock_istrategy

from PulseDeskUniversalStrategy import PulseDeskUniversalStrategy


MINIMAL_RULES = {
    "schema_version": "2.5",
    "timeframe": "5m",
    "symbols": ["BTC/USDT"],
    "entry": {
        "logic": "AND",
        "rules": [{"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": "<", "value": 30}],
    },
    "exit": {
        "logic": "AND",
        "rules": [{"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": ">", "value": 70}],
    },
    "filters": [],
    "position_sizing": {"type": "fixed_pct", "position_pct": 0.05},
    "risk": {"stoploss": -0.05, "max_open_trades": 3},
}


def _make_df(n=100, seed=42):
    rng = np.random.RandomState(seed)
    close = 100 + np.cumsum(rng.randn(n) * 0.5)
    return pd.DataFrame({
        "open": close - rng.uniform(0, 1, n),
        "high": close + rng.uniform(0, 2, n),
        "low": close - rng.uniform(0, 2, n),
        "close": close,
        "volume": rng.uniform(1e6, 5e6, n),
    })


@pytest.fixture
def rules_file(tmp_path):
    p = tmp_path / "strategy_rules.json"
    p.write_text(json.dumps(MINIMAL_RULES), encoding="utf-8")
    return p


@pytest.fixture
def strategy(rules_file):
    s = PulseDeskUniversalStrategy.__new__(PulseDeskUniversalStrategy)
    s._rules_cache = None
    s._rules_mtime = 0.0
    s._rules_hash = ""
    s._safe_hold = False
    s._safe_hold_reason = ""
    s._indicator_cache = {}
    s.timeframe = "5m"
    s.stoploss = -0.10
    s.trailing_stop = False
    s.trailing_stop_positive = None
    s.trailing_stop_positive_offset = 0.0
    with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
        yield s


@pytest.fixture
def df():
    return _make_df(100)


# ── Rules loading ───────────────────────────────────────────────────

class TestRulesLoading:
    def test_loads_rules_on_first_bot_loop(self, strategy, rules_file):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
        assert strategy._rules_cache is not None
        assert strategy._safe_hold is False

    def test_no_reload_if_mtime_unchanged(self, strategy, rules_file):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
            first_hash = strategy._rules_hash
            strategy.bot_loop_start()
            assert strategy._rules_hash == first_hash

    def test_reload_on_mtime_change(self, strategy, rules_file):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
            first_hash = strategy._rules_hash

            updated = MINIMAL_RULES.copy()
            updated["risk"] = {"stoploss": -0.08, "max_open_trades": 5}
            time.sleep(0.05)
            rules_file.write_text(json.dumps(updated), encoding="utf-8")

            strategy.bot_loop_start()
            assert strategy._rules_hash != first_hash
            assert strategy.stoploss == -0.08

    def test_missing_file_enters_safe_hold(self, strategy, tmp_path):
        missing = tmp_path / "nonexistent.json"
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(missing)}):
            strategy.bot_loop_start()
        assert strategy._safe_hold is True
        assert "missing" in strategy._safe_hold_reason


# ── Safe hold behavior ──────────────────────────────────────────────

class TestSafeHold:
    def test_safe_hold_blocks_entry(self, strategy, rules_file, df):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy._safe_hold = True
            strategy._safe_hold_reason = "test"
            result = strategy.populate_entry_trend(df, {})
            assert (result["enter_long"] == 0).all()

    def test_safe_hold_allows_exit(self, strategy, rules_file, df):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
            strategy.populate_indicators(df, {})

            strategy._safe_hold = True
            result = strategy.populate_exit_trend(df, {})
            assert "exit_long" in result.columns

    def test_invalid_schema_version_enters_safe_hold(self, strategy, rules_file):
        bad = MINIMAL_RULES.copy()
        bad["schema_version"] = "1.0"
        rules_file.write_text(json.dumps(bad), encoding="utf-8")
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
        assert strategy._safe_hold is True

    def test_invalid_json_enters_safe_hold(self, strategy, rules_file):
        rules_file.write_text("not json {{{", encoding="utf-8")
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
        assert strategy._safe_hold is True


# ── Risk config application ─────────────────────────────────────────

class TestRiskConfig:
    def test_stoploss_applied(self, strategy, rules_file):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
        assert strategy.stoploss == -0.05

    def test_trailing_stop_applied(self, strategy, rules_file):
        rules_with_trailing = MINIMAL_RULES.copy()
        rules_with_trailing["risk"] = {
            "stoploss": -0.07,
            "trailing_stop": True,
            "trailing_stop_positive": 0.02,
            "trailing_stop_positive_offset": 0.03,
            "max_open_trades": 5,
        }
        rules_file.write_text(json.dumps(rules_with_trailing), encoding="utf-8")
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
        assert strategy.trailing_stop is True
        assert strategy.trailing_stop_positive == 0.02
        assert strategy.trailing_stop_positive_offset == 0.03

    def test_timeframe_applied(self, strategy, rules_file):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
        assert strategy.timeframe == "5m"


# ── Full lifecycle ──────────────────────────────────────────────────

class TestLifecycle:
    def test_full_cycle_produces_signals(self, strategy, rules_file, df):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
            strategy.populate_indicators(df, {})
            entry = strategy.populate_entry_trend(df, {})
            exit_ = strategy.populate_exit_trend(df, {})

        assert "enter_long" in entry.columns
        assert "exit_long" in exit_.columns
        assert entry["enter_long"].dtype in (int, np.int64, np.int32, np.intp)

    def test_no_rules_no_entry(self, strategy, df):
        strategy._rules_cache = None
        result = strategy.populate_entry_trend(df, {})
        assert (result["enter_long"] == 0).all()

    def test_no_rules_no_crash_on_exit(self, strategy, df):
        strategy._rules_cache = None
        result = strategy.populate_exit_trend(df, {})
        assert (result["exit_long"] == 0).all()


# ── Fail-closed tests ──────────────────────────────────────────────

class TestFailClosed:
    def test_exception_in_indicators_no_crash(self, strategy, rules_file, df):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
            with patch("app.services.dsl_interpreter.compute_all_indicators", side_effect=RuntimeError("boom")):
                strategy.populate_indicators(df, {})
            assert strategy._indicator_cache == {}

    def test_exception_in_entry_defaults_to_no_entry(self, strategy, rules_file, df):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
            strategy.populate_indicators(df, {})
            with patch("app.services.dsl_interpreter.evaluate_group", side_effect=RuntimeError("boom")):
                result = strategy.populate_entry_trend(df, {})
            assert (result["enter_long"] == 0).all()

    def test_exception_in_exit_defaults_to_no_exit(self, strategy, rules_file, df):
        with patch.dict(os.environ, {"PULSEDESK_RULES_PATH": str(rules_file)}):
            strategy.bot_loop_start()
            strategy.populate_indicators(df, {})
            with patch("app.services.dsl_interpreter.evaluate_group", side_effect=RuntimeError("boom")):
                result = strategy.populate_exit_trend(df, {})
            assert (result["exit_long"] == 0).all()


# ── No eval/exec verification ──────────────────────────────────────

class TestNoEvalExec:
    def test_strategy_file_has_no_eval_or_exec(self):
        strategy_path = os.path.join(STRATEGY_DIR, "PulseDeskUniversalStrategy.py")
        source = Path(strategy_path).read_text(encoding="utf-8")
        assert "eval(" not in source
        assert "exec(" not in source

    def test_interpreter_file_has_no_eval_or_exec(self):
        interp_path = os.path.join(BACKEND_ROOT, "app", "services", "dsl_interpreter.py")
        source = Path(interp_path).read_text(encoding="utf-8")
        assert "eval(" not in source
        assert "exec(" not in source
