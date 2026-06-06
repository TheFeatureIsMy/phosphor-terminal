from __future__ import annotations

import logging
from sqlalchemy.orm import Session

from app.domain.runtime import DecisionSnapshot, RiskDecisionLog
from app.domain.snapshot import RuntimeDecisionSnapshot
from app.services.account_risk_firewall import AccountRiskState

logger = logging.getLogger(__name__)


class SnapshotPersistenceService:
    def __init__(self, db: Session):
        self._db = db

    def persist_snapshot(self, snapshot: RuntimeDecisionSnapshot) -> None:
        try:
            row = DecisionSnapshot(
                snapshot_uid=snapshot.snapshot_id,
                strategy_id=snapshot.strategy_id,
                strategy_version=snapshot.strategy_version,
                exchange=snapshot.exchange,
                symbol=snapshot.symbol,
                timeframe=snapshot.timeframe,
                candidate_signal=snapshot.candidate_signal.model_dump(),
                indicator_context=snapshot.indicator_context.model_dump(),
                structure_context=snapshot.structure_context.model_dump(),
                ai_context=snapshot.ai_context.model_dump(mode="json"),
                liquidity_execution_context=snapshot.liquidity_execution_context.model_dump(),
                risk_context=snapshot.risk_context.model_dump(),
                execution_plan=snapshot.execution_plan.model_dump(),
                final_decision=snapshot.execution_plan.decision,
                reject_reason=snapshot.execution_plan.reject_reason,
                confidence=snapshot.candidate_signal.confidence,
                reason_codes=snapshot.reason_codes,
                latency_ms=snapshot.latency_ms,
            )
            self._db.add(row)
            self._db.flush()
        except Exception:
            logger.exception("failed to persist snapshot %s", snapshot.snapshot_id)

    def persist_risk_log(self, snapshot_uid: str, risk_state: AccountRiskState, account_id: str) -> None:
        try:
            row = RiskDecisionLog(
                snapshot_uid=snapshot_uid,
                account_id=account_id,
                risk_state="allowed" if risk_state.allowed else "blocked",
                decision=risk_state.decision,
                reason_code=risk_state.reason_code,
                daily_pnl=risk_state.daily_pnl,
                weekly_pnl=risk_state.weekly_pnl,
            )
            self._db.add(row)
            self._db.flush()
        except Exception:
            logger.exception("failed to persist risk log for %s", snapshot_uid)
