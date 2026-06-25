"""Compute per-strategy impact of a manipulation case (would-block decision)."""
from __future__ import annotations

import logging
from typing import Any

from sqlalchemy.orm import Session

from app.domain.strategy import StrategyV2, StrategyVersion

logger = logging.getLogger(__name__)

_RULE_TYPE = "manipulation_score_filter"
_ACTIVE_STATUSES = {"active", "backtested", "draft"}


def _parse_dsl(raw: Any) -> dict:
    if isinstance(raw, dict):
        return raw
    return {}


def _find_filter_rule(dsl: dict) -> dict | None:
    for rule in dsl.get("rules") or []:
        if isinstance(rule, dict) and rule.get("type") == _RULE_TYPE:
            return rule
    return None


def _missing_layers(case: dict) -> bool:
    layers = case.get("evidence_layers")
    if not layers:
        return True
    expected = ("A_price", "B_orderbook", "C_onchain", "D_social", "E_cross_market")
    for key in expected:
        entry = layers.get(key)
        if entry is None or not entry.get("available"):
            return True
    return False


def _latest_version(strategy_id, db: Session) -> StrategyVersion | None:
    return (
        db.query(StrategyVersion)
        .filter(StrategyVersion.strategy_id == strategy_id)
        .order_by(StrategyVersion.version_no.desc())
        .first()
    )


def compute_strategy_impact(case: dict, db: Session) -> dict:
    """Scan active strategies, decide for each whether the manipulation case would be blocked."""
    case_symbol = (case.get("symbol") or "").strip()
    confidence = float(case.get("confidence") or 0.0)
    case_missing = _missing_layers(case)

    strategies = (
        db.query(StrategyV2)
        .filter(StrategyV2.status.in_(_ACTIVE_STATUSES))
        .all()
    )

    affected: list[dict] = []
    total_protected = 0
    for strat in strategies:
        version = _latest_version(strat.id, db)
        if version is None:
            continue
        dsl = _parse_dsl(version.rule_dsl)
        symbols = list(dsl.get("symbols") or [])
        matches = [sym for sym in symbols if sym == case_symbol]
        if symbols and not matches:
            continue  # symbol-targeted strategy that does not match

        rule = _find_filter_rule(dsl)

        if rule is None:
            status = {"enabled": False, "would_block": False, "reason_codes": ["filter_disabled"]}
        else:
            max_score = float(rule.get("max_score") or 1.0)
            policy = str(rule.get("missing_data_policy") or "reject")
            if confidence >= max_score:
                status = {
                    "enabled": True,
                    "would_block": True,
                    "reason_codes": [
                        "confidence_exceeds_max_score",
                        f"confidence={confidence:.2f}",
                        f"max_score={max_score:.2f}",
                    ],
                }
            elif case_missing and policy == "reject":
                status = {
                    "enabled": True,
                    "would_block": True,
                    "reason_codes": ["missing_data_policy_reject"],
                }
            else:
                status = {
                    "enabled": True,
                    "would_block": False,
                    "reason_codes": ["under_threshold"],
                }

        if status["would_block"]:
            total_protected += 1

        affected.append({
            "strategy_id": str(strat.id),
            "name": strat.name,
            "matches_symbols": matches or symbols,
            "manipulation_filter": status,
        })

    return {
        "case_id": case.get("id", ""),
        "affected_strategies": affected,
        "total_affected": len(affected),
        "total_protected": total_protected,
    }
