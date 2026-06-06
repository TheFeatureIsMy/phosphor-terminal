"""Reconciliation between PulseDesk local state and Freqtrade runtime."""
import uuid
import logging
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.domain.reconciliation import ReconciliationEvent, FreqtradeConnectionState
from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.order import ExecutionPosition
from app.domain.ledger import ExecutionLedgerEvent
from app.repositories.ledger_repository import LedgerRepository

logger = logging.getLogger(__name__)

SCHEMA_VERSION = "2.5"


class ReconciliationService:
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

    def start_reconciliation(
        self,
        strategy_run_id: uuid.UUID,
        freqtrade_run_id: uuid.UUID,
    ) -> ReconciliationEvent:
        """Create reconciliation event + write RECONCILIATION_STARTED to ledger."""
        event = ReconciliationEvent(
            strategy_run_id=strategy_run_id,
            freqtrade_run_id=freqtrade_run_id,
            status="started",
        )
        self._s.add(event)
        self._s.flush()  # materialise event.id

        # Update FreqtradeRun status to reconciliating
        ft_run = self._s.get(FreqtradeRun, freqtrade_run_id)
        if ft_run:
            ft_run.status = "reconciliating"

        # Write ledger event
        self._write_ledger(
            event_type="PULSEDESK_RECONCILIATION_STARTED",
            strategy_run_id=strategy_run_id,
            freqtrade_run_id=freqtrade_run_id,
            normalized_payload={"reconciliation_event_id": str(event.id)},
        )
        self._s.flush()
        return event

    def execute(
        self,
        reconciliation_event_id: uuid.UUID,
        freqtrade_positions: list[dict],
    ) -> dict:
        """Compare local positions vs Freqtrade REST state, produce drift summary."""
        event = self._s.get(ReconciliationEvent, reconciliation_event_id)
        if not event:
            raise ValueError(f"ReconciliationEvent {reconciliation_event_id} not found")

        # Get local open positions for this run
        local_positions = (
            self._s.query(ExecutionPosition)
            .filter(
                ExecutionPosition.strategy_run_id == event.strategy_run_id,
                ExecutionPosition.status == "open",
            )
            .all()
        )

        local_map = {p.symbol: p for p in local_positions}
        remote_map = {
            p.get("pair", p.get("symbol", "")): p for p in freqtrade_positions
        }

        drifts: list[dict] = []
        all_symbols = set(local_map.keys()) | set(remote_map.keys())
        for symbol in sorted(all_symbols):
            local = local_map.get(symbol)
            remote = remote_map.get(symbol)
            if local and not remote:
                drifts.append({
                    "symbol": symbol,
                    "type": "local_only",
                    "detail": "Position exists locally but not in Freqtrade",
                })
            elif remote and not local:
                drifts.append({
                    "symbol": symbol,
                    "type": "remote_only",
                    "detail": "Position exists in Freqtrade but not locally",
                })
            elif local and remote:
                # Amount drift check
                local_amount = float(local.amount) if local.amount is not None else 0.0
                remote_amount = float(remote.get("amount", 0))
                if abs(local_amount - remote_amount) > 1e-8:
                    drifts.append({
                        "symbol": symbol,
                        "type": "amount_mismatch",
                        "detail": f"Local amount={local_amount}, remote amount={remote_amount}",
                    })

        drift_summary = {"drifts": drifts, "total_drifts": len(drifts)}

        event.drift_summary = drift_summary
        event.local_positions = {
            "positions": [
                {
                    "symbol": p.symbol,
                    "amount": str(p.amount) if p.amount is not None else None,
                    "position_side": p.position_side,
                    "status": p.status,
                }
                for p in local_positions
            ],
        }
        event.remote_positions = {"positions": freqtrade_positions}
        self._s.flush()

        return drift_summary

    def complete(
        self,
        reconciliation_event_id: uuid.UUID,
        success: bool = True,
    ) -> ReconciliationEvent:
        """Mark reconciliation complete + write RECONCILIATION_COMPLETED to ledger."""
        event = self._s.get(ReconciliationEvent, reconciliation_event_id)
        if not event:
            raise ValueError(f"ReconciliationEvent {reconciliation_event_id} not found")

        event.status = "completed" if success else "failed"
        event.completed_at = self._now()

        # Restore FreqtradeRun status
        if event.freqtrade_run_id:
            ft_run = self._s.get(FreqtradeRun, event.freqtrade_run_id)
            if ft_run and ft_run.status == "reconciliating":
                ft_run.status = "running" if success else "failed"
                ft_run.last_reconciled_at = self._now()

        drift_count = 0
        if event.drift_summary:
            drift_count = len(event.drift_summary.get("drifts", []))

        self._write_ledger(
            event_type="PULSEDESK_RECONCILIATION_COMPLETED",
            strategy_run_id=event.strategy_run_id,
            freqtrade_run_id=event.freqtrade_run_id,
            normalized_payload={
                "reconciliation_event_id": str(event.id),
                "status": event.status,
                "drift_count": drift_count,
            },
        )
        self._s.flush()
        return event

    def is_reconciliating(self, freqtrade_run_id: uuid.UUID) -> bool:
        """Check if a run is currently in reconciliation state."""
        ft_run = self._s.get(FreqtradeRun, freqtrade_run_id)
        return ft_run is not None and ft_run.status == "reconciliating"
