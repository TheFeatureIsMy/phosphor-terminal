"""StrategyPromotionService — evaluates and executes PAPER_RUNNING→PAPER_PASSED promotion."""
from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.domain.enums import StrategyVersionStatus, StrategyRunMode
from app.domain.execution import StrategyRun
from app.domain.ledger import ExecutionLedgerEvent
from app.domain.strategy import StrategyVersion
from app.repositories.ledger_repository import LedgerRepository
from app.services.strategy_transition import validate_transition, is_system_only

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _naive(value: datetime | None) -> datetime | None:
    return value.replace(tzinfo=None) if value is not None and value.tzinfo else value


@dataclass
class PromotionCriteria:
    min_dryrun_hours: float = 72.0
    min_win_rate: float = 0.4
    min_total_trades: int = 5
    max_circuit_breaker_trips: int = 0


@dataclass
class PromotionResult:
    eligible: bool
    reason: str


@dataclass
class TradeStats:
    total_trades: int
    win_rate: float


class StrategyPromotionService:
    def __init__(self, db: Session, criteria: PromotionCriteria | None = None):
        self._db = db
        self._criteria = criteria or PromotionCriteria()

    def evaluate_promotion(self, strategy_run_id: uuid.UUID) -> PromotionResult:
        run = self._db.get(StrategyRun, strategy_run_id)
        if not run:
            return PromotionResult(eligible=False, reason="run_not_found")
        if run.mode != StrategyRunMode.DRY_RUN.value:
            return PromotionResult(eligible=False, reason="not_a_dryrun")

        version = self._db.get(StrategyVersion, run.strategy_version_id)
        if not version:
            return PromotionResult(eligible=False, reason="version_not_found")
        if version.status != StrategyVersionStatus.PAPER_RUNNING.value:
            return PromotionResult(eligible=False, reason=f"wrong_status:{version.status}")

        # 1. Duration check
        if not run.started_at:
            return PromotionResult(eligible=False, reason="not_started")
        duration_hours = (_utcnow() - _naive(run.started_at)).total_seconds() / 3600
        if duration_hours < self._criteria.min_dryrun_hours:
            return PromotionResult(
                eligible=False,
                reason=f"duration_{duration_hours:.1f}h_lt_{self._criteria.min_dryrun_hours}h",
            )

        # 2. Circuit breaker check
        cb_trips = self._count_circuit_breaker_trips(strategy_run_id)
        if cb_trips > self._criteria.max_circuit_breaker_trips:
            return PromotionResult(eligible=False, reason="circuit_breaker_tripped")

        # 3. Trade stats check
        stats = self._compute_trade_stats(strategy_run_id)
        if stats.total_trades < self._criteria.min_total_trades:
            return PromotionResult(
                eligible=False,
                reason=f"insufficient_trades_{stats.total_trades}_lt_{self._criteria.min_total_trades}",
            )
        if stats.win_rate < self._criteria.min_win_rate:
            return PromotionResult(
                eligible=False,
                reason=f"win_rate_{stats.win_rate:.2%}_lt_{self._criteria.min_win_rate:.0%}",
            )

        return PromotionResult(eligible=True, reason="all_criteria_met")

    def promote_if_eligible(self, strategy_run_id: uuid.UUID) -> bool:
        result = self.evaluate_promotion(strategy_run_id)
        if not result.eligible:
            return False

        run = self._db.get(StrategyRun, strategy_run_id)
        version = self._db.get(StrategyVersion, run.strategy_version_id)

        from_status = StrategyVersionStatus(version.status)
        to_status = StrategyVersionStatus.PAPER_PASSED

        validate_transition(from_status, to_status)

        version.status = to_status.value
        self._db.flush()

        # Write promotion ledger event
        self._write_promotion_event(run, version, from_status, to_status, result.reason)
        logger.info(
            "Strategy version %s promoted: %s → %s",
            version.id, from_status.value, to_status.value,
        )
        return True

    def _count_circuit_breaker_trips(self, strategy_run_id: uuid.UUID) -> int:
        stmt = (
            select(func.count())
            .select_from(ExecutionLedgerEvent)
            .where(
                ExecutionLedgerEvent.strategy_run_id == strategy_run_id,
                ExecutionLedgerEvent.event_type.in_([
                    "PULSEDESK_CIRCUIT_BREAKER_TRIPPED",
                    "CIRCUIT_BREAKER_TRIPPED",
                ]),
            )
        )
        return self._db.scalar(stmt) or 0

    def _compute_trade_stats(self, strategy_run_id: uuid.UUID) -> TradeStats:
        stmt = (
            select(ExecutionLedgerEvent)
            .where(
                ExecutionLedgerEvent.strategy_run_id == strategy_run_id,
                ExecutionLedgerEvent.event_type == "FREQTRADE_TRADE_CLOSED",
            )
        )
        events = list(self._db.scalars(stmt).all())
        total = len(events)
        if total == 0:
            return TradeStats(total_trades=0, win_rate=0.0)

        wins = 0
        for evt in events:
            payload = evt.normalized_payload or {}
            profit = payload.get("profit_ratio") or payload.get("profit_abs") or 0
            if float(profit) > 0:
                wins += 1

        return TradeStats(total_trades=total, win_rate=wins / total)

    def _write_promotion_event(
        self, run: StrategyRun, version: StrategyVersion,
        from_status: StrategyVersionStatus, to_status: StrategyVersionStatus,
        reason: str,
    ) -> None:
        ledger = LedgerRepository(self._db)
        now = _utcnow()
        payload = {
            "strategy_version_id": str(version.id),
            "strategy_id": str(version.strategy_id),
            "from_status": from_status.value,
            "to_status": to_status.value,
            "reason": reason,
        }
        event_hash = LedgerRepository.compute_event_hash(
            "pulsedesk", f"promote-{version.id}", "PULSEDESK_STRATEGY_PROMOTED", payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(),
            event_time=now,
            event_type="PULSEDESK_STRATEGY_PROMOTED",
            source_system="pulsedesk",
            source_event_id=f"promote-{version.id}",
            event_hash=event_hash,
            strategy_run_id=run.id,
            correlation_id=run.id,
            normalized_payload=payload,
        )
        ledger.append(evt)
