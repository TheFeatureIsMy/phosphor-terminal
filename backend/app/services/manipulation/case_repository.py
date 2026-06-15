"""Manipulation case repository — CRUD + auto-discovery for manipulation cases."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


class ManipulationCaseRepository:
    """In-memory case store (v1). Will migrate to DB when PostgreSQL is wired."""

    def __init__(self):
        self._cases: dict[str, dict] = {}
        self._alerts: list[dict] = []

    def create_case(
        self, symbol: str, market: str, manipulation_type: str,
        confidence: float, evidence: dict, source: str = "rule_engine"
    ) -> dict:
        case_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()
        case = {
            "id": case_id,
            "symbol": symbol,
            "market": market,
            "manipulation_type": manipulation_type,
            "lifecycle_stage": "suspected",
            "confidence": confidence,
            "evidence": evidence,
            "timeline": [{"stage": "suspected", "entered_at": now, "confidence": confidence}],
            "outcome": {},
            "similar_cases": [],
            "auto_discovered": True,
            "source": source,
            "created_at": now,
            "updated_at": now,
            "completed_at": None,
        }
        self._cases[case_id] = case
        self._add_alert(case_id, "new_case", "info",
                        f"New manipulation case: {symbol} ({manipulation_type})")
        return case

    def get_case(self, case_id: str) -> dict | None:
        return self._cases.get(case_id)

    def list_cases(
        self, stage: str | None = None, symbol: str | None = None,
        manipulation_type: str | None = None, active_only: bool = True
    ) -> list[dict]:
        cases = list(self._cases.values())
        if active_only:
            completed = {"completed", "false_alarm"}
            cases = [c for c in cases if c["lifecycle_stage"] not in completed]
        if stage:
            cases = [c for c in cases if c["lifecycle_stage"] == stage]
        if symbol:
            cases = [c for c in cases if c["symbol"].lower() == symbol.lower()]
        if manipulation_type:
            cases = [c for c in cases if c["manipulation_type"] == manipulation_type]
        return sorted(cases, key=lambda c: c["created_at"], reverse=True)

    def update_stage(self, case_id: str, new_stage: str, confidence: float = 0.0,
                     features_snapshot: dict | None = None) -> dict | None:
        case = self._cases.get(case_id)
        if not case:
            return None
        old_stage = case["lifecycle_stage"]
        if old_stage == new_stage:
            return case
        now = datetime.now(timezone.utc).isoformat()
        case["lifecycle_stage"] = new_stage
        case["confidence"] = confidence
        case["updated_at"] = now
        case["timeline"].append({
            "stage": new_stage,
            "entered_at": now,
            "confidence": confidence,
            "features_snapshot": features_snapshot or {},
        })
        if new_stage in ("completed", "false_alarm"):
            case["completed_at"] = now
        severity = "critical" if new_stage in ("distribute", "collapse") else "warning"
        self._add_alert(
            case_id, "stage_change", severity,
            f"{case['symbol']}: {old_stage} → {new_stage}"
        )
        logger.info("Case %s stage: %s → %s (confidence=%.2f)", case_id, old_stage, new_stage, confidence)
        return case

    def set_outcome(self, case_id: str, outcome: dict) -> dict | None:
        case = self._cases.get(case_id)
        if not case:
            return None
        case["outcome"] = outcome
        case["updated_at"] = datetime.now(timezone.utc).isoformat()
        return case

    def get_alerts(self, limit: int = 20) -> list[dict]:
        return sorted(self._alerts, key=lambda a: a["created_at"], reverse=True)[:limit]

    def get_radar_overview(self) -> dict:
        active = self.list_cases(active_only=True)
        by_stage: dict[str, int] = {}
        high_risk: list[str] = []
        for c in active:
            stage = c["lifecycle_stage"]
            by_stage[stage] = by_stage.get(stage, 0) + 1
            if c["lifecycle_stage"] in ("distribute", "collapse") or c["confidence"] > 0.7:
                high_risk.append(c["symbol"])
        return {
            "active_cases": [self._to_summary(c) for c in active],
            "total_active": len(active),
            "by_stage": by_stage,
            "high_risk_symbols": list(set(high_risk)),
            "recent_alerts": self.get_alerts(limit=10),
        }

    def _add_alert(self, case_id: str, alert_type: str, severity: str, title: str,
                   detail: dict | None = None, trading_signal: dict | None = None):
        alert = {
            "id": str(uuid.uuid4()),
            "case_id": case_id,
            "alert_type": alert_type,
            "severity": severity,
            "title": title,
            "detail": detail or {},
            "trading_signal": trading_signal,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        self._alerts.append(alert)

    def _to_summary(self, case: dict) -> dict:
        return {
            "id": case["id"],
            "symbol": case["symbol"],
            "manipulation_type": case["manipulation_type"],
            "lifecycle_stage": case["lifecycle_stage"],
            "confidence": case["confidence"],
            "trading_signal_action": "",
            "created_at": case["created_at"],
        }
