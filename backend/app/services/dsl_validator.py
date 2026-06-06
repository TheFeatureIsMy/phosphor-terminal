"""StrategyRuleDSL Validator — structured error codes per §12, safe hold per §11."""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

from pydantic import ValidationError

from app.domain.dsl import (
    RulePackage, DSLIndicator, DSLOperator, DSLRuleType,
    SUPPORTED_SCHEMA_VERSIONS, ALLOWED_TIMEFRAMES,
    ALLOWED_MISSING_DATA_POLICIES, INDICATORS_REQUIRING_PERIOD,
)
from app.services.dsl_hasher import compute_dsl_hash

INDICATOR_VALUES = {e.value for e in DSLIndicator}
OPERATOR_VALUES = {e.value for e in DSLOperator}
RULE_TYPE_VALUES = {e.value for e in DSLRuleType}
INDICATORS_REQUIRING_PERIOD_VALUES = {e.value for e in INDICATORS_REQUIRING_PERIOD}

_SYMBOL_RE = re.compile(r"^[A-Z0-9]{2,10}/[A-Z0-9]{2,10}$")

SAFE_HOLD_CODES = {
    "DSL_SCHEMA_VERSION_UNSUPPORTED",
    "DSL_HASH_MISMATCH",
}


@dataclass
class DSLError:
    code: str
    path: str
    message: str
    severity: str = "error"


@dataclass
class ValidationReport:
    valid: bool = True
    error_count: int = 0
    warning_count: int = 0
    safe_hold_required: bool = False
    safe_hold_reasons: list[str] = field(default_factory=list)
    errors: list[DSLError] = field(default_factory=list)
    warnings: list[DSLError] = field(default_factory=list)
    parsed: Any = None

    def add_error(self, code: str, message: str, path: str = "") -> None:
        self.errors.append(DSLError(code=code, path=path, message=message))
        self.error_count += 1
        self.valid = False


# Backward-compatible alias
ValidationResult = ValidationReport


class DSLValidator:
    def validate(self, dsl: dict[str, Any]) -> ValidationReport:
        sv = dsl.get("schema_version")
        if sv == "3.0":
            return self._validate_v3(dsl)
        return self._validate_v25(dsl)

    def _validate_v3(self, dsl: dict[str, Any]) -> ValidationReport:
        report = ValidationReport()
        try:
            from app.domain.dsl import RulePackageV3
            parsed = RulePackageV3.model_validate(dsl)
            report.parsed = parsed
        except Exception as e:
            err_msg = str(e)
            if len(err_msg) > 500:
                err_msg = err_msg[:500] + "..."
            report.add_error("DSL_V3_VALIDATION_FAILED", err_msg)
        return report

    def _validate_v25(self, dsl: dict[str, Any]) -> ValidationReport:
        errors: list[DSLError] = []
        warnings: list[DSLError] = []

        self._check_schema_version(dsl, errors)
        self._check_timeframe(dsl, errors)
        self._check_symbols(dsl, errors)
        self._check_rules_group(dsl, "entry", errors, warnings)
        self._check_rules_group(dsl, "exit", errors, warnings)
        self._check_filters(dsl, errors, warnings)
        self._check_position_sizing(dsl, errors)
        self._check_risk(dsl, errors)
        self._check_dsl_hash(dsl, errors)

        if errors:
            safe_hold, reasons = self._compute_safe_hold(errors)
            return ValidationReport(
                valid=False,
                error_count=len(errors),
                warning_count=len(warnings),
                safe_hold_required=safe_hold,
                safe_hold_reasons=reasons,
                errors=errors,
                warnings=warnings,
            )

        try:
            parsed = RulePackage.model_validate(dsl)
        except ValidationError as exc:
            for e in exc.errors():
                loc = ".".join(str(p) for p in e["loc"])
                errors.append(DSLError(
                    code="DSL_MISSING_REQUIRED_FIELD",
                    path=loc,
                    message=e["msg"],
                ))
            safe_hold, reasons = self._compute_safe_hold(errors)
            return ValidationReport(
                valid=False,
                error_count=len(errors),
                warning_count=len(warnings),
                safe_hold_required=safe_hold,
                safe_hold_reasons=reasons,
                errors=errors,
                warnings=warnings,
            )

        return ValidationReport(
            valid=True,
            error_count=0,
            warning_count=len(warnings),
            safe_hold_required=False,
            safe_hold_reasons=[],
            errors=[],
            warnings=warnings,
            parsed=parsed,
        )

    # ── Checks ──────────────────────────────────────────────────────

    def _check_schema_version(self, dsl: dict, errors: list[DSLError]):
        sv = dsl.get("schema_version")
        if sv is None:
            errors.append(DSLError("DSL_MISSING_REQUIRED_FIELD", "schema_version", "schema_version is required"))
        elif sv not in SUPPORTED_SCHEMA_VERSIONS:
            errors.append(DSLError("DSL_SCHEMA_VERSION_UNSUPPORTED", "schema_version", f"schema_version '{sv}' not supported"))

    def _check_timeframe(self, dsl: dict, errors: list[DSLError]):
        tf = dsl.get("timeframe")
        if tf is None:
            errors.append(DSLError("DSL_MISSING_REQUIRED_FIELD", "timeframe", "timeframe is required"))
        elif tf not in ALLOWED_TIMEFRAMES:
            errors.append(DSLError("DSL_TIMEFRAME_NOT_ALLOWED", "timeframe", f"timeframe '{tf}' not allowed"))

    def _check_symbols(self, dsl: dict, errors: list[DSLError]):
        syms = dsl.get("symbols")
        if not syms or not isinstance(syms, list) or len(syms) == 0:
            errors.append(DSLError("DSL_MISSING_REQUIRED_FIELD", "symbols", "symbols must be a non-empty list"))
            return
        for i, sym in enumerate(syms):
            if not isinstance(sym, str) or not _SYMBOL_RE.match(sym):
                errors.append(DSLError(
                    "DSL_SYMBOL_NOT_ALLOWED", f"symbols[{i}]",
                    f"symbol '{sym}' must match BASE/QUOTE format (e.g. BTC/USDT)",
                ))

    def _check_rules_group(self, dsl: dict, group_name: str, errors: list[DSLError], warnings: list[DSLError]):
        group = dsl.get(group_name)
        if group is None:
            errors.append(DSLError("DSL_MISSING_REQUIRED_FIELD", group_name, f"{group_name} is required"))
            return
        rules = group.get("rules", [])
        if not rules:
            errors.append(DSLError("DSL_MISSING_REQUIRED_FIELD", f"{group_name}.rules", f"{group_name}.rules must be non-empty"))
            return
        for i, rule in enumerate(rules):
            self._check_rule(rule, f"{group_name}.rules[{i}]", errors, warnings)

    def _check_filters(self, dsl: dict, errors: list[DSLError], warnings: list[DSLError]):
        filters = dsl.get("filters", [])
        for i, rule in enumerate(filters):
            self._check_rule(rule, f"filters[{i}]", errors, warnings)

    def _check_rule(self, rule: dict, path: str, errors: list[DSLError], warnings: list[DSLError]):
        if not isinstance(rule, dict):
            errors.append(DSLError("DSL_MISSING_REQUIRED_FIELD", path, "rule must be an object"))
            return

        rt = rule.get("type")
        if rt is None:
            errors.append(DSLError("DSL_MISSING_REQUIRED_FIELD", f"{path}.type", "rule type is required"))
        elif rt not in RULE_TYPE_VALUES:
            errors.append(DSLError("DSL_UNSUPPORTED_RULE_TYPE", f"{path}.type", f"rule type '{rt}' not allowed"))

        ind = rule.get("indicator")
        if ind is not None and ind not in INDICATOR_VALUES:
            errors.append(DSLError("DSL_UNSUPPORTED_INDICATOR", f"{path}.indicator", f"indicator '{ind}' not allowed"))

        cross_ind = rule.get("cross_indicator")
        if cross_ind is not None and cross_ind not in INDICATOR_VALUES:
            errors.append(DSLError("DSL_UNSUPPORTED_INDICATOR", f"{path}.cross_indicator", f"indicator '{cross_ind}' not allowed"))

        op = rule.get("operator")
        if op is not None and op not in OPERATOR_VALUES:
            errors.append(DSLError("DSL_UNSUPPORTED_OPERATOR", f"{path}.operator", f"operator '{op}' not allowed"))

        # Missing data policy validation (§7)
        if rt == "manipulation_score_filter":
            policy = rule.get("missing_data_policy", "reject")
            if policy not in ALLOWED_MISSING_DATA_POLICIES:
                errors.append(DSLError(
                    "DSL_MISSING_DATA_POLICY_INVALID", f"{path}.missing_data_policy",
                    f"missing_data_policy '{policy}' not allowed; must be one of: {sorted(ALLOWED_MISSING_DATA_POLICIES)}",
                ))

        # Indicator params warning
        if ind is not None and ind in INDICATORS_REQUIRING_PERIOD_VALUES:
            params = rule.get("params", {})
            if not params.get("period"):
                warnings.append(DSLError(
                    "DSL_INDICATOR_REQUIRES_PARAMS", f"{path}.params.period",
                    f"indicator '{ind}' typically requires params.period",
                    severity="warning",
                ))

    def _check_position_sizing(self, dsl: dict, errors: list[DSLError]):
        ps = dsl.get("position_sizing")
        if ps is None:
            errors.append(DSLError("DSL_MISSING_REQUIRED_FIELD", "position_sizing", "position_sizing is required"))
            return
        pct = ps.get("position_pct")
        if pct is not None and (not isinstance(pct, (int, float)) or pct <= 0 or pct > 1):
            errors.append(DSLError("DSL_INVALID_POSITION_PCT", "position_sizing.position_pct", f"position_pct must be in (0, 1], got {pct}"))

    def _check_risk(self, dsl: dict, errors: list[DSLError]):
        risk = dsl.get("risk")
        if risk is None:
            errors.append(DSLError("DSL_RISK_FIELD_MISSING", "risk", "risk is required"))
            return
        if "stoploss" not in risk:
            errors.append(DSLError("DSL_RISK_FIELD_MISSING", "risk.stoploss", "stoploss is required"))
        elif not isinstance(risk["stoploss"], (int, float)) or risk["stoploss"] >= 0:
            errors.append(DSLError("DSL_RISK_FIELD_MISSING", "risk.stoploss", "stoploss must be negative"))
        if "max_open_trades" not in risk:
            errors.append(DSLError("DSL_RISK_FIELD_MISSING", "risk.max_open_trades", "max_open_trades is required"))

        # Trailing stop consistency
        ts = risk.get("trailing_stop")
        tsp = risk.get("trailing_stop_positive")
        tspo = risk.get("trailing_stop_positive_offset")

        if tsp is not None and ts is not True:
            errors.append(DSLError(
                "DSL_TRAILING_STOP_INCONSISTENT", "risk.trailing_stop",
                "trailing_stop_positive requires trailing_stop=true",
            ))
        if tspo is not None and tsp is not None:
            if tspo <= tsp:
                errors.append(DSLError(
                    "DSL_TRAILING_STOP_INCONSISTENT", "risk.trailing_stop_positive_offset",
                    f"trailing_stop_positive_offset ({tspo}) must be > trailing_stop_positive ({tsp})",
                ))

    def _check_dsl_hash(self, dsl: dict, errors: list[DSLError]):
        provided = dsl.get("dsl_hash")
        if provided is None:
            return
        computed = compute_dsl_hash(dsl)
        if provided != computed:
            errors.append(DSLError(
                "DSL_HASH_MISMATCH", "dsl_hash",
                f"provided dsl_hash does not match computed hash",
            ))

    # ── Safe Hold ───────────────────────────────────────────────────

    def _compute_safe_hold(self, errors: list[DSLError]) -> tuple[bool, list[str]]:
        if not errors:
            return False, []

        reasons: list[str] = []
        error_codes = {e.code for e in errors}

        if "DSL_SCHEMA_VERSION_UNSUPPORTED" in error_codes:
            reasons.append("schema_version unsupported")
        if "DSL_HASH_MISMATCH" in error_codes:
            reasons.append("dsl_hash mismatch")
        if not reasons:
            reasons.append("DSL validation failed")

        return True, reasons
