"""Manipulation case repository — CRUD + auto-discovery for manipulation cases."""
from __future__ import annotations

import logging
import math
import uuid
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

LAYER_KEYS = ("A_price", "B_orderbook", "C_onchain", "D_social", "E_cross_market")
COMPLETED_STAGES = {"completed", "false_alarm"}


class ManipulationCaseRepository:
    """In-memory case store (v1). Will migrate to DB when PostgreSQL is wired."""

    def __init__(self):
        self._cases: dict[str, dict] = {}
        self._alerts: list[dict] = []

    def create_case(
        self, symbol: str, market: str, manipulation_type: str,
        confidence: float, evidence: dict, source: str = "rule_engine",
        evidence_layers: dict[str, dict] | None = None,
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
            "evidence_layers": evidence_layers,
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
        try:
            from app.services.manipulation.pubsub import publish_event
            publish_event({
                "type": "new_case",
                "case_id": case_id,
                "symbol": symbol,
                "manipulation_type": manipulation_type,
                "initial_stage": "suspected",
                "confidence": confidence,
                "timestamp": now,
            })
        except Exception:
            pass
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
        try:
            from app.services.manipulation.pubsub import publish_event
            publish_event({
                "type": "stage_change",
                "case_id": case_id,
                "symbol": case["symbol"],
                "old_stage": old_stage,
                "new_stage": new_stage,
                "confidence": confidence,
                "timestamp": now,
            })
        except Exception:
            pass
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

    def find_similar(self, case_id: str, top_n: int = 5) -> list[dict]:
        """Find top-N completed cases by cosine similarity over per-layer scores."""
        focal = self._cases.get(case_id)
        if not focal or not focal.get("evidence_layers"):
            return []
        focal_vec = self._layer_vector(focal["evidence_layers"])
        if not any(focal_vec):
            return []
        scored: list[tuple[float, dict]] = []
        for other in self._cases.values():
            if other["id"] == case_id:
                continue
            if other["lifecycle_stage"] not in COMPLETED_STAGES:
                continue
            if not other.get("evidence_layers"):
                continue
            other_vec = self._layer_vector(other["evidence_layers"])
            sim = self._cosine(focal_vec, other_vec)
            scored.append((sim, other))
        scored.sort(key=lambda t: t[0], reverse=True)
        return [{
            "id": c["id"],
            "symbol": c["symbol"],
            "manipulation_type": c["manipulation_type"],
            "similarity": round(sim, 4),
            "outcome": c.get("outcome") or {},
            "completed_at": c.get("completed_at"),
        } for sim, c in scored[:top_n]]

    @staticmethod
    def _layer_vector(layers: dict[str, dict]) -> list[float]:
        vec = []
        for key in LAYER_KEYS:
            entry = layers.get(key) or {}
            score = entry.get("score")
            vec.append(float(score) if score is not None else 0.0)
        return vec

    @staticmethod
    def _cosine(a: list[float], b: list[float]) -> float:
        dot = sum(x * y for x, y in zip(a, b))
        na = math.sqrt(sum(x * x for x in a))
        nb = math.sqrt(sum(y * y for y in b))
        if na == 0 or nb == 0:
            return 0.0
        return dot / (na * nb)

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
