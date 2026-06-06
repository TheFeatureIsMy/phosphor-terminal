"""Tests for the RiskEngine.pre_backtest_check method."""

import pytest

from app.services.risk_engine import RiskEngine


def _valid_dsl():
    """Return a valid DSL dictionary for testing."""
    return {
        "schema_version": "2.5",
        "timeframe": "1h",
        "symbols": ["BTC/USDT"],
        "entry": {
            "logic": "AND",
            "rules": [
                {
                    "type": "indicator_threshold",
                    "indicator": "rsi",
                    "params": {"period": 14},
                    "operator": "<",
                    "value": 30,
                }
            ],
        },
        "exit": {
            "logic": "OR",
            "rules": [
                {
                    "type": "indicator_threshold",
                    "indicator": "rsi",
                    "params": {"period": 14},
                    "operator": ">",
                    "value": 70,
                }
            ],
        },
        "filters": [],
        "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
        "risk": {"stoploss": -0.05, "max_open_trades": 3},
        "metadata": {},
    }


VALID_TIMERANGE = "20250101-20250601"
VALID_CAPITAL = 10000.0


class TestRiskEngine:
    """Tests for RiskEngine.pre_backtest_check."""

    def setup_method(self):
        self.engine = RiskEngine()

    # 1. Happy path
    def test_valid_dsl_passes(self):
        result = self.engine.pre_backtest_check(
            _valid_dsl(), VALID_TIMERANGE, VALID_CAPITAL
        )
        assert result.approved is True
        assert result.errors == []

    # 2. Unsupported schema version
    def test_invalid_schema_version_rejected(self):
        dsl = _valid_dsl()
        dsl["schema_version"] = "1.0"
        result = self.engine.pre_backtest_check(dsl, VALID_TIMERANGE, VALID_CAPITAL)
        assert result.approved is False
        error_codes = [e["code"] for e in result.errors]
        assert "DSL_SCHEMA_VERSION_UNSUPPORTED" in error_codes

    # 3. Missing stoploss
    def test_missing_stoploss_rejected(self):
        dsl = _valid_dsl()
        del dsl["risk"]["stoploss"]
        result = self.engine.pre_backtest_check(dsl, VALID_TIMERANGE, VALID_CAPITAL)
        assert result.approved is False

    # 4. Invalid timerange format
    def test_invalid_timerange_format(self):
        result = self.engine.pre_backtest_check(
            _valid_dsl(), "2025-01-01 to 2025-06-01", VALID_CAPITAL
        )
        assert result.approved is False
        error_codes = [e["code"] for e in result.errors]
        assert "BACKTEST_INVALID_TIMERANGE" in error_codes

    # 5. Start date after end date
    def test_timerange_start_after_end(self):
        result = self.engine.pre_backtest_check(
            _valid_dsl(), "20250601-20250101", VALID_CAPITAL
        )
        assert result.approved is False
        error_codes = [e["code"] for e in result.errors]
        assert "BACKTEST_INVALID_TIMERANGE" in error_codes

    # 6. End date far in the future
    def test_timerange_future_end(self):
        result = self.engine.pre_backtest_check(
            _valid_dsl(), "20250101-20990101", VALID_CAPITAL
        )
        assert result.approved is False
        error_codes = [e["code"] for e in result.errors]
        assert "BACKTEST_INVALID_TIMERANGE" in error_codes

    # 7. Zero capital
    def test_zero_capital_rejected(self):
        result = self.engine.pre_backtest_check(
            _valid_dsl(), VALID_TIMERANGE, 0
        )
        assert result.approved is False
        error_codes = [e["code"] for e in result.errors]
        assert "BACKTEST_INVALID_CAPITAL" in error_codes

    # 8. Negative capital
    def test_negative_capital_rejected(self):
        result = self.engine.pre_backtest_check(
            _valid_dsl(), VALID_TIMERANGE, -100
        )
        assert result.approved is False
        error_codes = [e["code"] for e in result.errors]
        assert "BACKTEST_INVALID_CAPITAL" in error_codes

    # 9. Unsupported operator
    def test_invalid_operator_rejected(self):
        dsl = _valid_dsl()
        dsl["entry"]["rules"][0]["operator"] = "LIKE"
        result = self.engine.pre_backtest_check(dsl, VALID_TIMERANGE, VALID_CAPITAL)
        assert result.approved is False
        error_codes = [e["code"] for e in result.errors]
        assert "DSL_UNSUPPORTED_OPERATOR" in error_codes

    # 10. Valid DSL returns a parsed dsl_report
    def test_valid_dsl_returns_parsed(self):
        result = self.engine.pre_backtest_check(
            _valid_dsl(), VALID_TIMERANGE, VALID_CAPITAL
        )
        assert result.dsl_report is not None
        assert result.dsl_report.parsed is not None


class TestManipulationCheck:
    def setup_method(self):
        self.engine = RiskEngine()

    def test_score_above_80_rejected(self):
        result = self.engine.manipulation_check("SCAM/USDT", 85.0)
        assert result.approved is False
        assert any(e["code"] == "MANIPULATION_SCORE_EXTREME" for e in result.errors)

    def test_score_60_to_80_approved_with_warning(self):
        result = self.engine.manipulation_check("RISKY/USDT", 65.0)
        assert result.approved is True
        assert any(e["code"] == "MANIPULATION_SCORE_HIGH" for e in result.errors)

    def test_score_below_60_clean(self):
        result = self.engine.manipulation_check("BTC/USDT", 30.0)
        assert result.approved is True
        assert len(result.errors) == 0
