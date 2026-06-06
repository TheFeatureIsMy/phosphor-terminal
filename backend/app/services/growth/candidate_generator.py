"""Candidate generator — builds StrategyCandidate from report + existing DSL.

Generates improvement suggestions as a new DSL candidate. Does NOT auto-execute.
"""
from __future__ import annotations

from dataclasses import asdict
from typing import Any

from app.schemas.growth import Finding, StrategyCandidateData, TradeMetrics
from app.services.dsl_hasher import compute_dsl_hash
from app.services.dsl_validator import DSLValidator


def generate_candidate(
    report_id: Any,
    source_version_id: Any,
    source_dsl: dict[str, Any],
    metrics: TradeMetrics,
    findings: list[Finding],
) -> StrategyCandidateData:
    candidate_dsl = _apply_suggestions(dict(source_dsl), metrics, findings)
    candidate_dsl.pop("dsl_hash", None)
    candidate_dsl["dsl_hash"] = compute_dsl_hash(candidate_dsl)

    validator = DSLValidator()
    validation = validator.validate(candidate_dsl)

    rationale_parts: list[str] = []
    for f in findings:
        if f.category in ("weakness", "risk"):
            rationale_parts.append(f.description)
    rationale = "; ".join(rationale_parts) if rationale_parts else "Performance review adjustments"

    return StrategyCandidateData(
        source_growth_report_id=report_id,
        source_strategy_version_id=source_version_id,
        candidate_dsl=candidate_dsl,
        candidate_dsl_hash=candidate_dsl.get("dsl_hash", ""),
        rationale=rationale,
        dsl_valid=validation.valid,
        dsl_errors=[asdict(e) for e in validation.errors],
        auto_execute=False,
        status="draft",
    )


def _apply_suggestions(dsl: dict[str, Any], metrics: TradeMetrics, findings: list[Finding]) -> dict[str, Any]:
    risk = dsl.get("risk", {})

    if metrics.max_drawdown_pct > 10.0:
        current_sl = risk.get("stoploss", -0.10)
        tighter = max(current_sl * 0.8, -0.03)
        risk["stoploss"] = round(tighter, 4)

    if metrics.profit_factor > 0 and metrics.profit_factor < 1.0:
        current_mot = risk.get("max_open_trades", 3)
        risk["max_open_trades"] = max(1, current_mot - 1)

    if not risk.get("trailing_stop") and metrics.win_rate >= 0.5 and metrics.avg_profit_pct > 2.0:
        risk["trailing_stop"] = True
        risk["trailing_stop_positive"] = 0.01
        risk["trailing_stop_positive_offset"] = 0.02

    dsl["risk"] = risk

    ps = dsl.get("position_sizing", {})
    if metrics.max_drawdown_pct > 15.0:
        current_pct = ps.get("position_pct", 0.05)
        ps["position_pct"] = round(max(0.01, current_pct * 0.7), 4)
        dsl["position_sizing"] = ps

    return dsl
