"""Precondition checker — 7 gates that must all pass before live_small."""
from __future__ import annotations

from app.schemas.live_small import PreconditionItem, PreconditionReport, RunHistoryStats

MIN_DRYRUN_HOURS = 72.0
REQUIRED_STATUS = "paper_passed"


def check_preconditions(stats: RunHistoryStats) -> PreconditionReport:
    items: list[PreconditionItem] = [
        _check_status(stats),
        _check_backtest(stats),
        _check_dryrun_duration(stats),
        _check_dryrun_health(stats),
        _check_risk_binding(stats),
        _check_human_confirm(stats),
        _check_no_active_run(stats),
    ]
    return PreconditionReport(
        all_passed=all(i.passed for i in items),
        items=items,
    )


def _check_status(s: RunHistoryStats) -> PreconditionItem:
    ok = s.strategy_version_status == REQUIRED_STATUS
    return PreconditionItem(
        name="strategy_version_status",
        passed=ok,
        reason="" if ok else f"Status is '{s.strategy_version_status}', required '{REQUIRED_STATUS}'",
    )


def _check_backtest(s: RunHistoryStats) -> PreconditionItem:
    ok = s.backtest_count >= 1
    return PreconditionItem(
        name="backtest_exists",
        passed=ok,
        reason="" if ok else "No backtest record found for this DSL version",
    )


def _check_dryrun_duration(s: RunHistoryStats) -> PreconditionItem:
    ok = s.dryrun_count >= 1 and s.longest_dryrun_hours >= MIN_DRYRUN_HOURS
    reason = ""
    if s.dryrun_count == 0:
        reason = "No dry-run record found"
    elif s.longest_dryrun_hours < MIN_DRYRUN_HOURS:
        reason = f"Longest dry-run is {s.longest_dryrun_hours:.1f}h, required >= {MIN_DRYRUN_HOURS}h"
    return PreconditionItem(name="dryrun_duration", passed=ok, reason=reason)


def _check_dryrun_health(s: RunHistoryStats) -> PreconditionItem:
    ok = not s.dryrun_had_failure
    return PreconditionItem(
        name="dryrun_health",
        passed=ok,
        reason="" if ok else "Dry-run had failed or manual_review_required status",
    )


def _check_risk_binding(s: RunHistoryStats) -> PreconditionItem:
    ok = s.has_risk_policy_binding
    return PreconditionItem(
        name="risk_policy_binding",
        passed=ok,
        reason="" if ok else "No active RiskPolicy + CapitalPool binding for live_small mode",
    )


def _check_human_confirm(s: RunHistoryStats) -> PreconditionItem:
    ok = s.capital_pool_requires_human_confirm
    return PreconditionItem(
        name="human_confirm_required",
        passed=ok,
        reason="" if ok else "CapitalPool.requires_human_confirm must be true",
    )


def _check_no_active_run(s: RunHistoryStats) -> PreconditionItem:
    ok = not s.active_live_small_run_exists
    return PreconditionItem(
        name="no_active_live_small",
        passed=ok,
        reason="" if ok else "Another live_small run is already active for this strategy",
    )
