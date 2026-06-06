"""Execution Ledger Service — business logic for append-only event recording."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.ledger import ExecutionLedgerEvent
from app.repositories.ledger_repository import LedgerRepository

SCHEMA_VERSION = "2.5"


class LedgerService:
    def __init__(self, session: Session):
        self._s = session
        self._repo = LedgerRepository(session)

    def record_event(
        self, *,
        event_type: str,
        source_system: str,
        normalized_payload: dict,
        event_time: datetime | None = None,
        source_event_id: str | None = None,
        raw_payload: dict | None = None,
        strategy_run_id: uuid.UUID | None = None,
        freqtrade_run_id: uuid.UUID | None = None,
        command_id: uuid.UUID | None = None,
        trade_intent_id: uuid.UUID | None = None,
        risk_decision_id: uuid.UUID | None = None,
        symbol: str | None = None,
        sequence_no: int | None = None,
        correlation_id: uuid.UUID | None = None,
        causation_id: uuid.UUID | None = None,
    ) -> tuple[ExecutionLedgerEvent, bool]:
        now = event_time or datetime.now(timezone.utc)

        event_hash = LedgerRepository.compute_event_hash(
            source_system, source_event_id, event_type, normalized_payload, now,
        )

        event = ExecutionLedgerEvent(
            id=uuid.uuid4(),
            event_time=now,
            event_type=event_type,
            source_system=source_system,
            source_event_id=source_event_id,
            event_hash=event_hash,
            strategy_run_id=strategy_run_id,
            freqtrade_run_id=freqtrade_run_id,
            command_id=command_id,
            trade_intent_id=trade_intent_id,
            risk_decision_id=risk_decision_id,
            symbol=symbol,
            sequence_no=sequence_no,
            schema_version=SCHEMA_VERSION,
            correlation_id=correlation_id,
            causation_id=causation_id,
            raw_payload=raw_payload,
            normalized_payload=normalized_payload,
        )

        return self._repo.append(event)

    def get_event(self, event_id: uuid.UUID) -> Optional[ExecutionLedgerEvent]:
        return self._repo.get_by_id(event_id)

    def get_event_chain(
        self, correlation_id: uuid.UUID, *, offset: int = 0, limit: int = 100,
    ) -> list[ExecutionLedgerEvent]:
        return self._repo.list_by_correlation_id(correlation_id, offset=offset, limit=limit)

    def list_events(
        self, *,
        strategy_run_id: uuid.UUID | None = None,
        command_id: uuid.UUID | None = None,
        correlation_id: uuid.UUID | None = None,
        event_type: str | None = None,
        source_system: str | None = None,
        symbol: str | None = None,
        offset: int = 0,
        limit: int = 100,
    ) -> list[ExecutionLedgerEvent]:
        return self._repo.list_events(
            strategy_run_id=strategy_run_id,
            command_id=command_id,
            correlation_id=correlation_id,
            event_type=event_type,
            source_system=source_system,
            symbol=symbol,
            offset=offset,
            limit=limit,
        )
