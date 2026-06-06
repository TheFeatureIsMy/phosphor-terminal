"""RiskEngine — pre-deployment / pre-backtest / pre-dryrun risk gate (ADR-004 Layer 1)."""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime, date
from typing import Any

from app.services.dsl_validator import DSLValidator, ValidationReport

_TIMERANGE_RE = re.compile(r"^(\d{8})-(\d{8})$")


@dataclass
class RiskCheckResult:
    approved: bool
    errors: list[dict[str, str]] = field(default_factory=list)
    dsl_report: ValidationReport | None = None

    def add_error(self, code: str, message: str) -> None:
        self.errors.append({"code": code, "message": message})
        self.approved = False


class RiskEngine:
    def __init__(self) -> None:
        self._validator = DSLValidator()

    def _validate_dsl(self, dsl: dict[str, Any], result: RiskCheckResult) -> bool:
        report = self._validator.validate(dsl)
        result.dsl_report = report
        if not report.valid:
            result.approved = False
            for err in report.errors:
                result.add_error(err.code, err.message)
            return False
        return True

    def pre_backtest_check(
        self,
        dsl: dict[str, Any],
        timerange: str,
        initial_capital: float,
    ) -> RiskCheckResult:
        result = RiskCheckResult(approved=True)
        if not self._validate_dsl(dsl, result):
            return result
        self._check_timerange(timerange, result)
        self._check_capital(initial_capital, result)
        return result

    def pre_dryrun_check(
        self,
        dsl: dict[str, Any],
        stake_amount: float,
        initial_wallet: float,
        max_open_trades: int,
    ) -> RiskCheckResult:
        result = RiskCheckResult(approved=True)
        if not self._validate_dsl(dsl, result):
            return result
        if stake_amount <= 0:
            result.add_error("DRYRUN_INVALID_STAKE", "stake_amount must be positive")
        if initial_wallet <= 0:
            result.add_error("DRYRUN_INVALID_WALLET", "initial_wallet must be positive")
        if max_open_trades < 1:
            result.add_error("DRYRUN_INVALID_MAX_TRADES", "max_open_trades must be >= 1")
        if stake_amount > 0 and initial_wallet > 0:
            if stake_amount * max_open_trades > initial_wallet:
                result.add_error(
                    "DRYRUN_STAKE_EXCEEDS_WALLET",
                    f"stake_amount ({stake_amount}) * max_open_trades ({max_open_trades}) "
                    f"exceeds initial_wallet ({initial_wallet})",
                )
        return result

    def _check_timerange(self, timerange: str, result: RiskCheckResult) -> None:
        m = _TIMERANGE_RE.match(timerange)
        if not m:
            result.add_error(
                "BACKTEST_INVALID_TIMERANGE",
                f"timerange must be YYYYMMDD-YYYYMMDD, got '{timerange}'",
            )
            return
        try:
            start = datetime.strptime(m.group(1), "%Y%m%d").date()
            end = datetime.strptime(m.group(2), "%Y%m%d").date()
        except ValueError:
            result.add_error("BACKTEST_INVALID_TIMERANGE", f"invalid date in timerange '{timerange}'")
            return
        if start >= end:
            result.add_error("BACKTEST_INVALID_TIMERANGE", "start date must be before end date")
        if end > date.today():
            result.add_error("BACKTEST_INVALID_TIMERANGE", "end date cannot be in the future")

    def _check_capital(self, initial_capital: float, result: RiskCheckResult) -> None:
        if initial_capital <= 0:
            result.add_error("BACKTEST_INVALID_CAPITAL", "initial_capital must be positive")

    def pre_live_small_check(
        self,
        dsl: dict[str, Any],
        capital_pool: dict[str, Any],
        run_history: dict[str, Any] | None = None,
        symbol: str | None = None,
        manipulation_score: float | None = None,
    ) -> RiskCheckResult:
        result = RiskCheckResult(approved=True)

        if not self._validate_dsl(dsl, result):
            return result

        risk = dsl.get("risk", {})

        # stoploss must exist and be negative
        sl = risk.get("stoploss")
        if sl is None or sl >= 0:
            result.add_error("LIVE_SMALL_NO_STOPLOSS", "stoploss must exist and be negative for live_small")

        # max_open_trades must be bounded
        mot = risk.get("max_open_trades")
        if mot is None or mot < 1:
            result.add_error("LIVE_SMALL_INVALID_MAX_TRADES", "max_open_trades must be >= 1")

        # CapitalPool safety checks
        pool_budget = capital_pool.get("total_budget", 0)
        if pool_budget <= 0:
            result.add_error("LIVE_SMALL_NO_BUDGET", "total_budget must be positive")

        if capital_pool.get("allow_leverage", False) is not False:
            result.add_error("LIVE_SMALL_LEVERAGE_FORBIDDEN", "allow_leverage must be false for live_small")

        if capital_pool.get("allow_auto_trade", False) is not False:
            result.add_error("LIVE_SMALL_AUTO_TRADE_FORBIDDEN", "allow_auto_trade must be false for live_small")

        if capital_pool.get("requires_human_confirm", False) is not True:
            result.add_error("LIVE_SMALL_CONFIRM_REQUIRED", "requires_human_confirm must be true")

        # stake x max_open_trades must fit within budget
        max_pos_pct = capital_pool.get("max_position_pct_per_trade", 0.03)
        if mot and pool_budget > 0:
            stake = pool_budget * max_pos_pct
            if stake * mot > pool_budget * 1.01:
                result.add_error(
                    "LIVE_SMALL_EXPOSURE_EXCEEDS_BUDGET",
                    f"stake ({stake:.2f}) × max_open_trades ({mot}) exceeds total_budget ({pool_budget:.2f})",
                )

        # max_daily_loss_pct sanity
        max_daily = capital_pool.get("max_daily_loss_pct", 0.03)
        if max_daily > 0.10:
            result.add_error("LIVE_SMALL_DAILY_LOSS_TOO_HIGH", f"max_daily_loss_pct ({max_daily}) exceeds 10%")

        # Manipulation check integration
        if symbol and manipulation_score is not None:
            manip_result = self.manipulation_check(symbol, manipulation_score)
            if not manip_result.approved:
                for err in manip_result.errors:
                    result.add_error(err["code"], err["message"])

        return result

    def manipulation_check(self, symbol: str, manipulation_score: float) -> RiskCheckResult:
        result = RiskCheckResult(approved=True)
        if manipulation_score >= 80:
            result.add_error(
                "MANIPULATION_SCORE_EXTREME",
                f"manipulation_score ({manipulation_score:.1f}) >= 80 for {symbol} — live trade blocked",
            )
        elif manipulation_score >= 60:
            result.errors.append({
                "code": "MANIPULATION_SCORE_HIGH",
                "message": f"manipulation_score ({manipulation_score:.1f}) >= 60 for {symbol} — caution advised",
            })
        return result

    @staticmethod
    def four_layer_position_clip(
        dsl_pct: float,
        risk_policy_pct: float | None,
        capital_pool_remaining_pct: float | None,
        freqtrade_limit_pct: float | None,
    ) -> float:
        """Take minimum of all 4 layers. None values are skipped."""
        values = [dsl_pct]
        if risk_policy_pct is not None:
            values.append(risk_policy_pct)
        if capital_pool_remaining_pct is not None:
            values.append(capital_pool_remaining_pct)
        if freqtrade_limit_pct is not None:
            values.append(freqtrade_limit_pct)
        return min(values)

    def pre_deployment_check(
        self, dsl: dict, risk_policy: dict | None = None, capital_pool: dict | None = None,
    ) -> RiskCheckResult:
        """Comprehensive pre-deployment risk check: DSL + RiskPolicy + CapitalPool."""
        errors: list[dict[str, str]] = []

        # 1. DSL validation
        dsl_report = self._validator.validate(dsl)
        if not dsl_report.valid:
            for err in dsl_report.errors:
                errors.append({"code": err.code, "message": err.message})

        # 2. RiskPolicy checks (if provided)
        if risk_policy:
            if not risk_policy.get("stoploss"):
                errors.append({"code": "RISK_MISSING_STOPLOSS", "message": "RiskPolicy must define stoploss"})

        # 3. CapitalPool checks (if provided)
        if capital_pool:
            if capital_pool.get("emergency_stop"):
                errors.append({"code": "CAPITAL_POOL_EMERGENCY", "message": "CapitalPool has emergency_stop enabled"})

        return RiskCheckResult(approved=len(errors) == 0, errors=errors, dsl_report=dsl_report)

    def portfolio_correlation_check(self, symbols: list[str], session) -> RiskCheckResult:
        """Check portfolio correlation risk across open positions."""
        from app.domain.order import ExecutionPosition

        errors: list[dict[str, str]] = []

        # Query active positions
        positions = session.query(ExecutionPosition).filter(
            ExecutionPosition.symbol.in_(symbols),
            ExecutionPosition.status == "open",
        ).all()

        # Check same-direction concentration
        direction_counts: dict[str, int] = {}
        for pos in positions:
            d = getattr(pos, "position_side", "unknown") or "unknown"
            direction_counts[d] = direction_counts.get(d, 0) + 1

        total = sum(direction_counts.values())
        if total > 0:
            for direction, count in direction_counts.items():
                ratio = count / total
                if ratio > 0.8 and total >= 3:
                    errors.append({
                        "code": "PORTFOLIO_CORRELATION_HIGH",
                        "message": f"{direction} concentration {ratio:.0%} across {total} positions",
                    })

        return RiskCheckResult(approved=len(errors) == 0, errors=errors, dsl_report=None)
