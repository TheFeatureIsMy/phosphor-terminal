"""Execution Ledger Repository — append-only, idempotent writes."""
import uuid
import hashlib
import json
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select, and_
from sqlalchemy.orm import Session

from app.domain.ledger import ExecutionLedgerEvent


class LedgerRepository:
    def __init__(self, session: Session):
        self._s = session

    @staticmethod
    def compute_event_hash(
        source_system: str, source_event_id: str | None,
        event_type: str, normalized_payload: dict,
        event_time: datetime | None = None,
    ) -> str:
        canonical = json.dumps(normalized_payload, sort_keys=True, default=str)
        if source_event_id:
            raw = f"{source_system}:{source_event_id}:{event_type}:{canonical}"
        else:
            bucket = (event_time or datetime.now(timezone.utc)).strftime("%Y-%m-%dT%H")
            raw = f"{source_system}:{event_type}:{bucket}:{canonical}"
        return hashlib.sha256(raw.encode()).hexdigest()

    def append(self, event: ExecutionLedgerEvent) -> tuple[ExecutionLedgerEvent, bool]:
        """Append event. Returns (event, created). Idempotent on both event_hash and source_event."""
        existing = self._find_by_hash(event.event_hash, event.event_time)
        if existing:
            return existing, False

        if event.source_event_id:
            existing = self.find_by_source_event(
                event.source_system, event.source_event_id,
                event.event_type, event.event_time,
            )
            if existing:
                return existing, False

        self._s.add(event)
        self._s.flush()
        return event, True

    def _find_by_hash(self, event_hash: str, event_time: datetime) -> Optional[ExecutionLedgerEvent]:
        stmt = select(ExecutionLedgerEvent).where(
            and_(
                ExecutionLedgerEvent.event_hash == event_hash,
                ExecutionLedgerEvent.event_time == event_time,
            )
        ).limit(1)
        return self._s.scalar(stmt)

    def find_by_source_event(
        self, source_system: str, source_event_id: str,
        event_type: str, event_time: datetime,
    ) -> Optional[ExecutionLedgerEvent]:
        stmt = select(ExecutionLedgerEvent).where(
            and_(
                ExecutionLedgerEvent.source_system == source_system,
                ExecutionLedgerEvent.source_event_id == source_event_id,
                ExecutionLedgerEvent.event_type == event_type,
                ExecutionLedgerEvent.event_time == event_time,
            )
        ).limit(1)
        return self._s.scalar(stmt)

    def get_by_id(self, event_id: uuid.UUID) -> Optional[ExecutionLedgerEvent]:
        stmt = select(ExecutionLedgerEvent).where(
            ExecutionLedgerEvent.id == event_id,
        ).limit(1)
        return self._s.scalar(stmt)

    def list_by_strategy_run(
        self, strategy_run_id: uuid.UUID, *, offset: int = 0, limit: int = 100,
    ) -> list[ExecutionLedgerEvent]:
        stmt = (
            select(ExecutionLedgerEvent)
            .where(ExecutionLedgerEvent.strategy_run_id == strategy_run_id)
            .order_by(ExecutionLedgerEvent.event_time.desc())
            .offset(offset).limit(limit)
        )
        return list(self._s.scalars(stmt).all())

    def list_by_command(
        self, command_id: uuid.UUID, *, offset: int = 0, limit: int = 100,
    ) -> list[ExecutionLedgerEvent]:
        stmt = (
            select(ExecutionLedgerEvent)
            .where(ExecutionLedgerEvent.command_id == command_id)
            .order_by(ExecutionLedgerEvent.event_time)
            .offset(offset).limit(limit)
        )
        return list(self._s.scalars(stmt).all())

    def list_by_correlation_id(
        self, correlation_id: uuid.UUID, *, offset: int = 0, limit: int = 100,
    ) -> list[ExecutionLedgerEvent]:
        stmt = (
            select(ExecutionLedgerEvent)
            .where(ExecutionLedgerEvent.correlation_id == correlation_id)
            .order_by(ExecutionLedgerEvent.event_time)
            .offset(offset).limit(limit)
        )
        return list(self._s.scalars(stmt).all())

    def list_by_event_type(
        self, event_type: str, *, offset: int = 0, limit: int = 100,
    ) -> list[ExecutionLedgerEvent]:
        stmt = (
            select(ExecutionLedgerEvent)
            .where(ExecutionLedgerEvent.event_type == event_type)
            .order_by(ExecutionLedgerEvent.event_time.desc())
            .offset(offset).limit(limit)
        )
        return list(self._s.scalars(stmt).all())

    def list_by_symbol(
        self, symbol: str, *, offset: int = 0, limit: int = 100,
    ) -> list[ExecutionLedgerEvent]:
        stmt = (
            select(ExecutionLedgerEvent)
            .where(ExecutionLedgerEvent.symbol == symbol)
            .order_by(ExecutionLedgerEvent.event_time.desc())
            .offset(offset).limit(limit)
        )
        return list(self._s.scalars(stmt).all())

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
        stmt = select(ExecutionLedgerEvent)
        filters = []
        if strategy_run_id:
            filters.append(ExecutionLedgerEvent.strategy_run_id == strategy_run_id)
        if command_id:
            filters.append(ExecutionLedgerEvent.command_id == command_id)
        if correlation_id:
            filters.append(ExecutionLedgerEvent.correlation_id == correlation_id)
        if event_type:
            filters.append(ExecutionLedgerEvent.event_type == event_type)
        if source_system:
            filters.append(ExecutionLedgerEvent.source_system == source_system)
        if symbol:
            filters.append(ExecutionLedgerEvent.symbol == symbol)
        if filters:
            stmt = stmt.where(and_(*filters))
        stmt = stmt.order_by(ExecutionLedgerEvent.event_time.desc()).offset(offset).limit(limit)
        return list(self._s.scalars(stmt).all())
