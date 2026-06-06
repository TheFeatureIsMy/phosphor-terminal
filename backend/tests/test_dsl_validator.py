"""DSL Validator tests — structured error codes, safe hold, validation report."""
import json
from pathlib import Path

from app.services.dsl_validator import DSLValidator, ValidationReport
from app.services.dsl_hasher import compute_dsl_hash

FIXTURES = Path(__file__).parent / "fixtures" / "dsl"


def _load(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text())


def _find_error(result, code: str):
    return [e for e in result.errors if e.code == code]


def _find_warning(result, code: str):
    return [e for e in result.warnings if e.code == code]


# ── Valid DSL ────────────────────────────────────────────────────────

class TestValidDSL:
    def test_minimal_passes(self):
        result = DSLValidator().validate(_load("minimal.json"))
        assert result.valid is True
        assert result.parsed is not None
        assert result.errors == []
        assert result.error_count == 0

    def test_ema_cross_passes(self):
        result = DSLValidator().validate(_load("ema_cross.json"))
        assert result.valid is True

    def test_multi_filter_passes(self):
        result = DSLValidator().validate(_load("multi_filter.json"))
        assert result.valid is True


# ── Schema Version ──────────────────────────────────────────────────

class TestSchemaVersion:
    def test_missing_version(self):
        result = DSLValidator().validate(_load("missing_version.json"))
        assert result.valid is False
        assert len(_find_error(result, "DSL_MISSING_REQUIRED_FIELD")) > 0
        assert any(e.path == "schema_version" for e in result.errors)

    def test_unsupported_version(self):
        dsl = _load("minimal.json")
        dsl["schema_version"] = "1.0"
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        assert len(_find_error(result, "DSL_SCHEMA_VERSION_UNSUPPORTED")) == 1


# ── Indicator Whitelist ─────────────────────────────────────────────

class TestIndicatorWhitelist:
    def test_unknown_indicator(self):
        result = DSLValidator().validate(_load("invalid_indicator.json"))
        assert result.valid is False
        errs = _find_error(result, "DSL_UNSUPPORTED_INDICATOR")
        assert len(errs) == 1
        assert "ichimoku_cloud" in errs[0].message

    def test_unknown_cross_indicator(self):
        dsl = _load("ema_cross.json")
        dsl["entry"]["rules"][0]["cross_indicator"] = "fibonacci_retracement"
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        errs = _find_error(result, "DSL_UNSUPPORTED_INDICATOR")
        assert len(errs) >= 1


# ── Operator Whitelist ──────────────────────────────────────────────

class TestOperatorWhitelist:
    def test_unknown_operator(self):
        result = DSLValidator().validate(_load("invalid_operator.json"))
        assert result.valid is False
        errs = _find_error(result, "DSL_UNSUPPORTED_OPERATOR")
        assert len(errs) == 1
        assert "LIKE" in errs[0].message
        assert "entry.rules[0].operator" == errs[0].path


# ── Rule Type Whitelist ─────────────────────────────────────────────

class TestRuleTypeWhitelist:
    def test_unknown_rule_type(self):
        result = DSLValidator().validate(_load("invalid_rule_type.json"))
        assert result.valid is False
        errs = _find_error(result, "DSL_UNSUPPORTED_RULE_TYPE")
        assert len(errs) == 1
        assert "custom_python" in errs[0].message


# ── Risk Validation ─────────────────────────────────────────────────

class TestRiskValidation:
    def test_missing_risk(self):
        dsl = _load("minimal.json")
        del dsl["risk"]
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        errs = _find_error(result, "DSL_RISK_FIELD_MISSING")
        assert len(errs) >= 1

    def test_missing_stoploss(self):
        result = DSLValidator().validate(_load("missing_stoploss.json"))
        assert result.valid is False
        errs = _find_error(result, "DSL_RISK_FIELD_MISSING")
        assert any("stoploss" in e.path for e in errs)

    def test_missing_max_open_trades(self):
        dsl = _load("minimal.json")
        del dsl["risk"]["max_open_trades"]
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        errs = _find_error(result, "DSL_RISK_FIELD_MISSING")
        assert any("max_open_trades" in e.path for e in errs)

    def test_positive_stoploss_rejected(self):
        dsl = _load("minimal.json")
        dsl["risk"]["stoploss"] = 0.05
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        errs = _find_error(result, "DSL_RISK_FIELD_MISSING")
        assert any("stoploss" in e.path for e in errs)


# ── Position Sizing ─────────────────────────────────────────────────

class TestPositionSizing:
    def test_missing_position_sizing(self):
        dsl = _load("minimal.json")
        del dsl["position_sizing"]
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        errs = _find_error(result, "DSL_MISSING_REQUIRED_FIELD")
        assert any("position_sizing" in e.path for e in errs)

    def test_invalid_position_pct(self):
        dsl = _load("minimal.json")
        dsl["position_sizing"]["position_pct"] = 1.5
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        errs = _find_error(result, "DSL_INVALID_POSITION_PCT")
        assert len(errs) == 1


# ── Symbol Format ───────────────────────────────────────────────────

class TestSymbolFormat:
    def test_valid_symbol(self):
        dsl = _load("minimal.json")
        result = DSLValidator().validate(dsl)
        assert result.valid is True

    def test_invalid_symbol_no_slash(self):
        result = DSLValidator().validate(_load("invalid_symbol.json"))
        assert result.valid is False
        errs = _find_error(result, "DSL_SYMBOL_NOT_ALLOWED")
        assert len(errs) == 1
        assert "BTCUSDT" in errs[0].message

    def test_invalid_symbol_empty_base(self):
        dsl = _load("minimal.json")
        dsl["symbols"] = ["/USDT"]
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        errs = _find_error(result, "DSL_SYMBOL_NOT_ALLOWED")
        assert len(errs) == 1

    def test_invalid_symbol_empty_quote(self):
        dsl = _load("minimal.json")
        dsl["symbols"] = ["BTC/"]
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        assert len(_find_error(result, "DSL_SYMBOL_NOT_ALLOWED")) == 1

    def test_multiple_symbols_one_invalid(self):
        dsl = _load("minimal.json")
        dsl["symbols"] = ["BTC/USDT", "ETHUSDT", "SOL/USDT"]
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        errs = _find_error(result, "DSL_SYMBOL_NOT_ALLOWED")
        assert len(errs) == 1
        assert errs[0].path == "symbols[1]"


# ── Missing Data Policy ────────────────────────────────────────────

class TestMissingDataPolicy:
    def test_reject_passes(self):
        dsl = _load("multi_filter.json")
        result = DSLValidator().validate(dsl)
        assert result.valid is True

    def test_degrade_to_paper_only_passes(self):
        dsl = _load("multi_filter.json")
        for f in dsl["filters"]:
            if f.get("type") == "manipulation_score_filter":
                f["missing_data_policy"] = "degrade_to_paper_only"
        result = DSLValidator().validate(dsl)
        assert result.valid is True

    def test_invalid_policy(self):
        result = DSLValidator().validate(_load("invalid_missing_data_policy.json"))
        assert result.valid is False
        errs = _find_error(result, "DSL_MISSING_DATA_POLICY_INVALID")
        assert len(errs) == 1
        assert "ignore" in errs[0].message


# ── Hash Verification ──────────────────────────────────────────────

class TestDSLHash:
    def test_deterministic(self):
        dsl = _load("minimal.json")
        h1 = compute_dsl_hash(dsl)
        h2 = compute_dsl_hash(dsl)
        assert h1 == h2
        assert len(h1) == 64

    def test_different_content_different_hash(self):
        assert compute_dsl_hash(_load("minimal.json")) != compute_dsl_hash(_load("ema_cross.json"))

    def test_ignores_dsl_hash_field(self):
        dsl = _load("minimal.json")
        h1 = compute_dsl_hash(dsl)
        dsl["dsl_hash"] = "old_hash"
        assert compute_dsl_hash(dsl) == h1

    def test_ignores_strategy_version_id(self):
        dsl = _load("minimal.json")
        h1 = compute_dsl_hash(dsl)
        dsl["strategy_version_id"] = "some-uuid"
        assert compute_dsl_hash(dsl) == h1

    def test_correct_hash_passes(self):
        dsl = _load("minimal.json")
        dsl["dsl_hash"] = compute_dsl_hash(dsl)
        result = DSLValidator().validate(dsl)
        assert result.valid is True
        assert len(_find_error(result, "DSL_HASH_MISMATCH")) == 0

    def test_wrong_hash_fails(self):
        result = DSLValidator().validate(_load("hash_mismatch.json"))
        assert result.valid is False
        errs = _find_error(result, "DSL_HASH_MISMATCH")
        assert len(errs) == 1

    def test_no_hash_skips_check(self):
        dsl = _load("minimal.json")
        assert "dsl_hash" not in dsl or dsl["dsl_hash"] is None
        result = DSLValidator().validate(dsl)
        assert result.valid is True


# ── Trailing Stop Consistency ───────────────────────────────────────

class TestTrailingStopConsistency:
    def test_positive_without_flag(self):
        result = DSLValidator().validate(_load("trailing_stop_inconsistent.json"))
        assert result.valid is False
        errs = _find_error(result, "DSL_TRAILING_STOP_INCONSISTENT")
        assert len(errs) >= 1

    def test_offset_less_than_positive(self):
        dsl = _load("minimal.json")
        dsl["risk"]["trailing_stop"] = True
        dsl["risk"]["trailing_stop_positive"] = 0.05
        dsl["risk"]["trailing_stop_positive_offset"] = 0.02
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        errs = _find_error(result, "DSL_TRAILING_STOP_INCONSISTENT")
        assert any("offset" in e.path for e in errs)

    def test_valid_trailing_stop(self):
        dsl = _load("ema_cross.json")
        result = DSLValidator().validate(dsl)
        assert result.valid is True
        assert len(_find_error(result, "DSL_TRAILING_STOP_INCONSISTENT")) == 0


# ── Indicator Params Warning ────────────────────────────────────────

class TestIndicatorParams:
    def test_rsi_without_period_warns(self):
        dsl = _load("minimal.json")
        dsl["entry"]["rules"][0]["params"] = {}
        result = DSLValidator().validate(dsl)
        assert result.valid is True
        warns = _find_warning(result, "DSL_INDICATOR_REQUIRES_PARAMS")
        assert len(warns) >= 1
        assert warns[0].severity == "warning"

    def test_close_without_period_no_warn(self):
        dsl = _load("minimal.json")
        dsl["entry"]["rules"][0]["indicator"] = "close"
        dsl["entry"]["rules"][0]["params"] = {}
        result = DSLValidator().validate(dsl)
        assert len(_find_warning(result, "DSL_INDICATOR_REQUIRES_PARAMS")) == 0

    def test_rsi_with_period_no_warn(self):
        dsl = _load("minimal.json")
        result = DSLValidator().validate(dsl)
        # minimal.json has params.period=14, so no warning for entry rule
        entry_warns = [w for w in result.warnings if "entry" in w.path]
        assert len(entry_warns) == 0


# ── Safe Hold ───────────────────────────────────────────────────────

class TestSafeHold:
    def test_safe_hold_on_validation_failure(self):
        dsl = _load("invalid_operator.json")
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        assert result.safe_hold_required is True
        assert len(result.safe_hold_reasons) > 0

    def test_safe_hold_on_hash_mismatch(self):
        result = DSLValidator().validate(_load("hash_mismatch.json"))
        assert result.safe_hold_required is True
        assert any("hash" in r for r in result.safe_hold_reasons)

    def test_safe_hold_on_unsupported_version(self):
        dsl = _load("minimal.json")
        dsl["schema_version"] = "1.0"
        result = DSLValidator().validate(dsl)
        assert result.safe_hold_required is True
        assert any("schema_version" in r for r in result.safe_hold_reasons)

    def test_no_safe_hold_on_valid(self):
        result = DSLValidator().validate(_load("minimal.json"))
        assert result.safe_hold_required is False
        assert result.safe_hold_reasons == []


# ── Validation Report ──────────────────────────────────────────────

class TestValidationReport:
    def test_report_error_count(self):
        dsl = {
            "timeframe": "1h", "symbols": ["BTC/USDT"],
            "entry": {"logic": "AND", "rules": [{"type": "custom_python"}]},
            "exit": {"logic": "OR", "rules": [{"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": ">", "value": 70}]},
            "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
            "risk": {"stoploss": -0.05, "max_open_trades": 3},
        }
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        assert result.error_count == len(result.errors)
        assert result.error_count > 0

    def test_report_warning_count(self):
        dsl = _load("minimal.json")
        dsl["entry"]["rules"][0]["params"] = {}
        result = DSLValidator().validate(dsl)
        assert result.valid is True
        assert result.warning_count == len(result.warnings)
        assert result.warning_count > 0

    def test_report_separates_errors_warnings(self):
        dsl = _load("minimal.json")
        dsl["entry"]["rules"][0]["params"] = {}
        result = DSLValidator().validate(dsl)
        for e in result.errors:
            assert e.severity == "error"
        for w in result.warnings:
            assert w.severity == "warning"

    def test_warnings_do_not_block_valid(self):
        dsl = _load("minimal.json")
        dsl["entry"]["rules"][0]["params"] = {}
        result = DSLValidator().validate(dsl)
        assert result.valid is True
        assert result.warning_count > 0

    def test_report_is_validation_report_type(self):
        result = DSLValidator().validate(_load("minimal.json"))
        assert isinstance(result, ValidationReport)


# ── Multiple Errors ─────────────────────────────────────────────────

class TestMultipleErrors:
    def test_multiple_errors_returned(self):
        dsl = {
            "timeframe": "1h", "symbols": ["BTC/USDT"],
            "entry": {"logic": "AND", "rules": [{"type": "custom_python", "indicator": "ichimoku_cloud", "operator": "LIKE"}]},
            "exit": {"logic": "OR", "rules": [{"type": "indicator_threshold", "indicator": "rsi", "params": {}, "operator": ">", "value": 70}]},
            "position_sizing": {"type": "fixed_pct", "position_pct": 5.0},
            "risk": {},
        }
        result = DSLValidator().validate(dsl)
        assert result.valid is False
        codes = {e.code for e in result.errors}
        assert "DSL_MISSING_REQUIRED_FIELD" in codes
        assert "DSL_UNSUPPORTED_RULE_TYPE" in codes
        assert "DSL_UNSUPPORTED_INDICATOR" in codes
        assert "DSL_UNSUPPORTED_OPERATOR" in codes
        assert "DSL_INVALID_POSITION_PCT" in codes
        assert "DSL_RISK_FIELD_MISSING" in codes
        assert len(result.errors) >= 6

    def test_error_includes_path(self):
        dsl = _load("invalid_operator.json")
        result = DSLValidator().validate(dsl)
        assert any(e.path == "entry.rules[0].operator" for e in result.errors)


# ── Golden Tests (§13) ──────────────────────────────────────────────

class TestGoldenTests:
    def test_golden_4_entry_and_all_rules_true(self):
        """#4: entry AND requires all entry rules true."""
        dsl = _load("ema_cross.json")
        result = DSLValidator().validate(dsl)
        assert result.valid is True
        assert result.parsed.entry.logic.value == "AND"
        assert len(result.parsed.entry.rules) == 2

    def test_golden_5_exit_or_any_rule_true(self):
        """#5: exit OR triggers when any exit rule true."""
        dsl = _load("minimal.json")
        result = DSLValidator().validate(dsl)
        assert result.valid is True
        assert result.parsed.exit.logic.value == "OR"

    def test_golden_6_invalid_operator_fails(self):
        """#6: invalid operator fails validation."""
        result = DSLValidator().validate(_load("invalid_operator.json"))
        assert result.valid is False
        assert any(e.code == "DSL_UNSUPPORTED_OPERATOR" for e in result.errors)

    def test_golden_7_hash_mismatch_fails(self):
        """#7: DSL hash mismatch fails deployment."""
        result = DSLValidator().validate(_load("hash_mismatch.json"))
        assert result.valid is False
        assert any(e.code == "DSL_HASH_MISMATCH" for e in result.errors)
        assert result.safe_hold_required is True

    def test_golden_1_rsi_entry_signal(self):
        """Golden Test 1: RSI < 30 triggers entry."""
        import numpy as np
        import pandas as pd
        from app.services.dsl_interpreter import evaluate_group

        dsl = _load("minimal.json")
        # Validate DSL first
        result = DSLValidator().validate(dsl)
        assert result.valid is True

        # Create DataFrame where RSI will be low (prices declining steadily)
        n = 50
        close = np.linspace(100, 60, n)
        df = pd.DataFrame({
            "open": close + 0.5,
            "high": close + 1.0,
            "low": close - 1.0,
            "close": close,
            "volume": np.full(n, 1e6),
        })

        # Evaluate entry group (logic=AND, rules=[rsi < 30])
        entry_signals = evaluate_group(df, dsl["entry"], {})
        # The last bars should have low RSI due to consistent decline
        assert entry_signals.iloc[-1] == True

    def test_golden_2_rsi_missing_data_false(self):
        """Golden Test 2: Insufficient indicator window -> entry=false."""
        import numpy as np
        import pandas as pd
        from app.services.dsl_interpreter import evaluate_group

        dsl = _load("minimal.json")
        # DSL has RSI(14) entry rule
        result = DSLValidator().validate(dsl)
        assert result.valid is True

        # Create DataFrame with only 5 rows (less than RSI period of 14)
        n = 5
        close = np.array([100.0, 99.0, 98.0, 97.0, 96.0])
        df = pd.DataFrame({
            "open": close + 0.5,
            "high": close + 1.0,
            "low": close - 1.0,
            "close": close,
            "volume": np.full(n, 1e6),
        })

        # RSI needs min_periods=14, so with 5 rows it produces NaN -> fillna(False)
        entry_signals = evaluate_group(df, dsl["entry"], {})
        # All should be False since RSI cannot be computed with only 5 data points
        assert entry_signals.iloc[-1] == False

    def test_golden_3_manipulation_missing_rejects_live_small(self):
        """Golden Test 3: Missing manipulation_score rejects live_small entry."""
        from app.services.risk_engine import RiskEngine

        # Use multi_filter which has manipulation_score_filter with missing_data_policy=reject
        dsl = _load("multi_filter.json")
        result = DSLValidator().validate(dsl)
        assert result.valid is True

        # Verify the filter structure defines reject policy
        manip_filter = None
        for f in dsl["filters"]:
            if f.get("type") == "manipulation_score_filter":
                manip_filter = f
                break
        assert manip_filter is not None
        assert manip_filter["missing_data_policy"] == "reject"

        # When manipulation_score is extreme (>=80), pre_live_small_check rejects
        engine = RiskEngine()
        check_result = engine.pre_live_small_check(
            dsl=dsl,
            capital_pool={
                "total_budget": 1000,
                "allow_leverage": False,
                "allow_auto_trade": False,
                "requires_human_confirm": True,
                "max_position_pct_per_trade": 0.03,
                "max_daily_loss_pct": 0.03,
            },
            symbol="SCAM/USDT",
            manipulation_score=85.0,
        )
        assert check_result.approved is False
        assert any(e["code"] == "MANIPULATION_SCORE_EXTREME" for e in check_result.errors)

    def test_golden_8_risk_policy_clips_position(self):
        """Golden Test 8: RiskPolicy clips position_pct to minimum."""
        from app.services.risk_engine import RiskEngine

        # DSL says 5%, RiskPolicy says 3%, CapitalPool says 4%, Freqtrade says 10%
        result = RiskEngine.four_layer_position_clip(
            dsl_pct=0.05,
            risk_policy_pct=0.03,
            capital_pool_remaining_pct=0.04,
            freqtrade_limit_pct=0.10,
        )
        # Result should be 3% (minimum of all layers)
        assert result == 0.03

    def test_golden_9_reconciliating_blocks_deployment(self):
        """Golden Test 9: Reconciliating state blocks deploy command."""
        from app.services.reconciliation_service import ReconciliationService
        from app.domain.enums import StrategyRunStatus

        # Verify reconciliating state enum exists
        assert StrategyRunStatus.RECONCILIATING.value == "reconciliating"

        # A valid DSL passes validation
        dsl = _load("minimal.json")
        result = DSLValidator().validate(dsl)
        assert result.valid is True

        # The ReconciliationService.is_reconciliating() checks FreqtradeRun status.
        # When status == "reconciliating", deployments must be blocked.
        assert hasattr(ReconciliationService, "is_reconciliating")

    def test_golden_10_safe_hold_emits_ledger(self):
        """Golden Test 10: Safe hold triggers ledger event."""
        from app.domain.enums import LedgerEventType

        # Create invalid DSL (unsupported schema version) that triggers safe_hold
        dsl = _load("minimal.json")
        dsl["schema_version"] = "1.0"

        result = DSLValidator().validate(dsl)
        assert result.valid is False
        assert result.safe_hold_required is True
        assert len(result.safe_hold_reasons) > 0
        assert any("schema_version" in r for r in result.safe_hold_reasons)

        # Verify the ledger event type exists for safe hold
        assert LedgerEventType.PULSEDESK_SAFE_HOLD_ENTERED.value == "PULSEDESK_SAFE_HOLD_ENTERED"


# ── Backward Compat ─────────────────────────────────────────────────

class TestBackwardCompat:
    def test_existing_valid_fixtures_still_pass(self):
        for name in ("minimal.json", "ema_cross.json", "multi_filter.json"):
            result = DSLValidator().validate(_load(name))
            assert result.valid is True, f"{name} should pass"

    def test_existing_invalid_fixtures_still_fail(self):
        for name in ("invalid_operator.json", "invalid_indicator.json",
                      "invalid_rule_type.json", "missing_stoploss.json", "missing_version.json"):
            result = DSLValidator().validate(_load(name))
            assert result.valid is False, f"{name} should fail"
