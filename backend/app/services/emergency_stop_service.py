"""Reusable emergency stop logic for both Command Bus handler and REST API."""
import uuid
import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.strategy import StrategyVersion
from app.domain.enums import StrategyVersionStatus
from app.domain.ledger import ExecutionLedgerEvent
from app.repositories.ledger_repository import LedgerRepository

logger = logging.getLogger(__name__)

SCHEMA_VERSION = "2.5"


class EmergencyStopService:
    def __init__(self, session: Session):
        self._s = session
        self._ledger = LedgerRepository(session)

    # ------------------------------------------------------------------
    # helpers
    # ------------------------------------------------------------------

    def _now(self) -> datetime:
        return datetime.now(timezone.utc)

    def _write_ledger(
        self,
        event_type: str,
        normalized_payload: dict,
        strategy_run_id: uuid.UUID | None = None,
        freqtrade_run_id: uuid.UUID | None = None,
    ) -> ExecutionLedgerEvent:
        now = self._now()
        event_hash = LedgerRepository.compute_event_hash(
            "pulsedesk", None, event_type, normalized_payload, now,
        )
        ledger_event = ExecutionLedgerEvent(
            id=uuid.uuid4(),
            event_time=now,
            event_type=event_type,
            source_system="pulsedesk",
            event_hash=event_hash,
            strategy_run_id=strategy_run_id,
            freqtrade_run_id=freqtrade_run_id,
            schema_version=SCHEMA_VERSION,
            normalized_payload=normalized_payload,
        )
        ledger_event, _created = self._ledger.append(ledger_event)
        return ledger_event

    # ------------------------------------------------------------------
    # public API
    # ------------------------------------------------------------------

    def stop(
        self,
        strategy_run_id: uuid.UUID | None = None,
        reason: str = "emergency_stop",
    ) -> dict:
        """Stop one or all active runs. Returns summary of stopped runs."""
        stopped_run_ids: list[uuid.UUID] = []
        ledger_event_ids: list[uuid.UUID] = []
        now = self._now()

        if strategy_run_id:
            stmt = select(StrategyRun).where(StrategyRun.id == strategy_run_id)
        else:
            # Stop ALL active runs
            stmt = select(StrategyRun).where(
                StrategyRun.status.in_(["created", "starting", "running", "degraded"])
            )

        runs = list(self._s.scalars(stmt).all())

        for run in runs:
            run.status = "stopped"
            run.stopped_at = now
            stopped_run_ids.append(run.id)

            # Stop associated FreqtradeRuns
            ft_stmt = select(FreqtradeRun).where(
                FreqtradeRun.strategy_run_id == run.id,
                FreqtradeRun.status.in_(
                    ["created", "starting", "running", "degraded", "reconciliating"]
                ),
            )
            ft_runs = list(self._s.scalars(ft_stmt).all())
            for ft_run in ft_runs:
                ft_run.status = "stopped"

            # Pause associated StrategyVersion
            if run.strategy_version_id:
                version = self._s.get(StrategyVersion, run.strategy_version_id)
                if version and version.status not in (
                    StrategyVersionStatus.ARCHIVED.value,
                    StrategyVersionStatus.REJECTED.value,
                    StrategyVersionStatus.PAUSED.value,
                ):
                    version.status = StrategyVersionStatus.PAUSED.value

            # Write ledger event
            ledger_event = self._write_ledger(
                event_type="PULSEDESK_EMERGENCY_STOP_REQUESTED",
                strategy_run_id=run.id,
                normalized_payload={
                    "reason": reason,
                    "strategy_run_id": str(run.id),
                    "action": "stop_all" if strategy_run_id is None else "stop_single",
                },
            )
            ledger_event_ids.append(ledger_event.id)

        self._s.flush()
        return {
            "stopped_runs": [str(rid) for rid in stopped_run_ids],
            "stopped_count": len(stopped_run_ids),
            "ledger_event_ids": [str(eid) for eid in ledger_event_ids],
            "reason": reason,
        }

    def resume(
        self,
        strategy_run_id: uuid.UUID,
        reason: str | None = None,
    ) -> dict:
        """Resume from emergency stop. Requires stopped or manual_review_required status."""
        run = self._s.get(StrategyRun, strategy_run_id)
        if not run:
            raise ValueError(f"StrategyRun {strategy_run_id} not found")
        if run.status not in ("stopped", "manual_review_required"):
            raise ValueError(
                f"Cannot resume run in status '{run.status}'. "
                "Must be 'stopped' or 'manual_review_required'."
            )

        run.status = "running"
        run.stopped_at = None

        # Resume associated FreqtradeRuns that were stopped
        ft_stmt = select(FreqtradeRun).where(
            FreqtradeRun.strategy_run_id == strategy_run_id,
            FreqtradeRun.status == "stopped",
        )
        ft_runs = list(self._s.scalars(ft_stmt).all())
        for ft_run in ft_runs:
            ft_run.status = "running"

        self._write_ledger(
            event_type="PULSEDESK_EMERGENCY_STOP_REQUESTED",
            strategy_run_id=strategy_run_id,
            normalized_payload={
                "reason": reason or "manual_resume",
                "strategy_run_id": str(strategy_run_id),
                "action": "resume",
            },
        )
        self._s.flush()
        return {
            "resumed_run": str(strategy_run_id),
            "resumed_freqtrade_runs": len(ft_runs),
            "message": "Run resumed successfully",
        }
