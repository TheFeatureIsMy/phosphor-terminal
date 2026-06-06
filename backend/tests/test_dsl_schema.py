"""StrategyRuleDSL Pydantic schema validation tests."""
import json
import os
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.domain.dsl import (
    RulePackage, RuleGroup, PositionSizing, RiskConfig,
    IndicatorThresholdRule, IndicatorCrossRule,
    DSLIndicator, DSLOperator, DSLRuleType,
)

FIXTURES = Path(__file__).parent / "fixtures" / "dsl"


def _load(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text())


class TestValidDSLParsing:
    def test_minimal_valid(self):
        dsl = _load("minimal.json")
        pkg = RulePackage.model_validate(dsl)
        assert pkg.schema_version == "2.5"
        assert pkg.timeframe == "1h"
        assert pkg.symbols == ["BTC/USDT"]
        assert len(pkg.entry.rules) == 1
        assert len(pkg.exit.rules) == 1
        assert pkg.position_sizing.position_pct == 0.02
        assert pkg.risk.stoploss == -0.05
        assert pkg.risk.max_open_trades == 3

    def test_ema_cross(self):
        dsl = _load("ema_cross.json")
        pkg = RulePackage.model_validate(dsl)
        assert pkg.timeframe == "4h"
        assert len(pkg.symbols) == 2
        assert len(pkg.entry.rules) == 2
        assert pkg.entry.rules[0].type == "indicator_cross"
        assert pkg.entry.rules[0].direction == "crosses_above"
        assert pkg.risk.trailing_stop is True
        assert len(pkg.filters) == 1

    def test_multi_filter(self):
        dsl = _load("multi_filter.json")
        pkg = RulePackage.model_validate(dsl)
        assert len(pkg.filters) == 6
        filter_types = [f.type for f in pkg.filters]
        assert "manipulation_score_filter" in filter_types
        assert "volume_filter" in filter_types
        assert "volatility_filter" in filter_types
        assert "cooldown_filter" in filter_types
        assert "portfolio_exposure_filter" in filter_types
        assert "signal_confirmation" in filter_types

    def test_between_operator(self):
        dsl = _load("multi_filter.json")
        pkg = RulePackage.model_validate(dsl)
        between_rule = pkg.entry.rules[0]
        assert between_rule.operator == "between"
        assert between_rule.min_value == 20
        assert between_rule.max_value == 40


class TestInvalidDSLRejection:
    def test_missing_schema_version(self):
        dsl = _load("minimal.json")
        del dsl["schema_version"]
        with pytest.raises(ValidationError) as exc_info:
            RulePackage.model_validate(dsl)
        errors = exc_info.value.errors()
        assert any("schema_version" in str(e["loc"]) for e in errors)

    def test_unsupported_schema_version(self):
        dsl = _load("minimal.json")
        dsl["schema_version"] = "1.0"
        with pytest.raises(ValidationError) as exc_info:
            RulePackage.model_validate(dsl)
        assert "not supported" in str(exc_info.value)

    def test_invalid_indicator(self):
        dsl = _load("invalid_indicator.json")
        with pytest.raises(ValidationError) as exc_info:
            RulePackage.model_validate(dsl)
        assert "ichimoku_cloud" in str(exc_info.value) or "indicator" in str(exc_info.value)

    def test_invalid_operator(self):
        dsl = _load("invalid_operator.json")
        with pytest.raises(ValidationError) as exc_info:
            RulePackage.model_validate(dsl)
        assert "LIKE" in str(exc_info.value) or "operator" in str(exc_info.value)

    def test_invalid_rule_type(self):
        dsl = _load("invalid_rule_type.json")
        with pytest.raises(ValidationError) as exc_info:
            RulePackage.model_validate(dsl)
        assert "custom_python" in str(exc_info.value) or "discriminator" in str(exc_info.value)

    def test_missing_stoploss(self):
        dsl = _load("missing_stoploss.json")
        with pytest.raises(ValidationError) as exc_info:
            RulePackage.model_validate(dsl)
        assert any("stoploss" in str(e["loc"]) for e in exc_info.value.errors())

    def test_missing_entry(self):
        dsl = _load("minimal.json")
        del dsl["entry"]
        with pytest.raises(ValidationError):
            RulePackage.model_validate(dsl)

    def test_missing_exit(self):
        dsl = _load("minimal.json")
        del dsl["exit"]
        with pytest.raises(ValidationError):
            RulePackage.model_validate(dsl)

    def test_empty_symbols(self):
        dsl = _load("minimal.json")
        dsl["symbols"] = []
        with pytest.raises(ValidationError):
            RulePackage.model_validate(dsl)

    def test_empty_entry_rules(self):
        dsl = _load("minimal.json")
        dsl["entry"]["rules"] = []
        with pytest.raises(ValidationError):
            RulePackage.model_validate(dsl)

    def test_invalid_timeframe(self):
        dsl = _load("minimal.json")
        dsl["timeframe"] = "7h"
        with pytest.raises(ValidationError) as exc_info:
            RulePackage.model_validate(dsl)
        assert "not allowed" in str(exc_info.value)

    def test_position_pct_zero(self):
        dsl = _load("minimal.json")
        dsl["position_sizing"]["position_pct"] = 0
        with pytest.raises(ValidationError):
            RulePackage.model_validate(dsl)

    def test_position_pct_over_one(self):
        dsl = _load("minimal.json")
        dsl["position_sizing"]["position_pct"] = 1.5
        with pytest.raises(ValidationError):
            RulePackage.model_validate(dsl)

    def test_stoploss_positive_rejected(self):
        dsl = _load("minimal.json")
        dsl["risk"]["stoploss"] = 0.05
        with pytest.raises(ValidationError):
            RulePackage.model_validate(dsl)

    def test_cross_operator_on_threshold_rule_rejected(self):
        dsl = _load("minimal.json")
        dsl["entry"]["rules"][0]["operator"] = "crosses_above"
        with pytest.raises(ValidationError) as exc_info:
            RulePackage.model_validate(dsl)
        assert "indicator_cross" in str(exc_info.value)

    def test_between_min_gt_max_rejected(self):
        dsl = _load("multi_filter.json")
        dsl["entry"]["rules"][0]["min_value"] = 50
        dsl["entry"]["rules"][0]["max_value"] = 20
        with pytest.raises(ValidationError) as exc_info:
            RulePackage.model_validate(dsl)
        assert "min_value" in str(exc_info.value)


class TestWhitelistEnums:
    def test_all_14_indicators(self):
        assert len(DSLIndicator) == 14

    def test_all_10_operators(self):
        assert len(DSLOperator) == 10

    def test_all_8_rule_types(self):
        assert len(DSLRuleType) == 8

    def test_indicator_values(self):
        expected = {"rsi", "ema", "sma", "macd", "macd_signal", "bb_upper",
                    "bb_lower", "atr", "volume", "volume_sma", "close", "open", "high", "low"}
        assert {i.value for i in DSLIndicator} == expected

    def test_operator_values(self):
        expected = {">", ">=", "<", "<=", "==", "!=", "crosses_above", "crosses_below", "between", "not_between"}
        assert {o.value for o in DSLOperator} == expected
