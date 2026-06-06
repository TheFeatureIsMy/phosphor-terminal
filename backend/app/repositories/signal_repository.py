"""Signal Repository — 统一查询接口，屏蔽冷热分层。"""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select, func, and_
from sqlalchemy.orm import Session

from app.domain.signal import (
    SignalIdentity, Signal, SignalPayload, SignalEvidence,
    SignalLifecycleEvent, SignalSnapshot,
)


class SignalRepository:
    def __init__(self, session: Session):
        self._s = session

    def create_signal(
        self, *, signal_id: uuid.UUID, source_type: str, symbol: str, market: str,
        direction: str, status: str, valid_from: datetime,
        confidence: float | None = None, score: float | None = None,
        risk_level: str | None = None, timeframe: str | None = None,
        source_id: uuid.UUID | None = None, source_name: str | None = None,
        expires_at: datetime | None = None, permission: dict | None = None,
    ) -> Signal:
        identity = SignalIdentity(id=signal_id)
        self._s.add(identity)
        self._s.flush()

        now = datetime.now(timezone.utc)
        sig = Signal(
            id=signal_id, created_at=now,
            source_type=source_type, source_id=source_id, source_name=source_name,
            symbol=symbol, market=market, timeframe=timeframe,
            direction=direction, confidence=confidence, score=score,
            risk_level=risk_level, status=status,
            permission=permission or {}, valid_from=valid_from,
            expires_at=expires_at, updated_at=now,
        )
        self._s.add(sig)
        self._s.flush()
        return sig

    def get_by_id(self, signal_id: uuid.UUID) -> Optional[Signal]:
        stmt = select(Signal).where(Signal.id == signal_id).limit(1)
        return self._s.scalar(stmt)

    def list_signals(
        self, *, symbol: str | None = None, status: str | None = None,
        source_type: str | None = None, direction: str | None = None,
        offset: int = 0, limit: int = 50,
    ) -> list[Signal]:
        stmt = select(Signal)
        filters = []
        if symbol:
            filters.append(Signal.symbol == symbol)
        if status:
            filters.append(Signal.status == status)
        if source_type:
            filters.append(Signal.source_type == source_type)
        if direction:
            filters.append(Signal.direction == direction)
        if filters:
            stmt = stmt.where(and_(*filters))
        stmt = stmt.order_by(Signal.created_at.desc()).offset(offset).limit(limit)
        return list(self._s.scalars(stmt).all())

    def count_signals(
        self, *, symbol: str | None = None, status: str | None = None,
    ) -> int:
        stmt = select(func.count()).select_from(Signal)
        if symbol:
            stmt = stmt.where(Signal.symbol == symbol)
        if status:
            stmt = stmt.where(Signal.status == status)
        return self._s.scalar(stmt) or 0

    def get_payload(self, signal_id: uuid.UUID) -> Optional[SignalPayload]:
        return self._s.get(SignalPayload, signal_id)

    def save_payload(self, payload: SignalPayload) -> SignalPayload:
        self._s.add(payload)
        self._s.flush()
        return payload

    def add_evidence(self, evidence: SignalEvidence) -> SignalEvidence:
        self._s.add(evidence)
        self._s.flush()
        return evidence

    def get_evidence(self, signal_id: uuid.UUID) -> list[SignalEvidence]:
        stmt = select(SignalEvidence).where(
            SignalEvidence.signal_id == signal_id
        ).order_by(SignalEvidence.created_at.desc())
        return list(self._s.scalars(stmt).all())

    def add_lifecycle_event(
        self, *, signal_id: uuid.UUID, event_type: str,
        from_status: str | None = None, to_status: str | None = None,
        reason: str | None = None, actor: str | None = None,
    ) -> SignalLifecycleEvent:
        evt = SignalLifecycleEvent(
            signal_id=signal_id, event_type=event_type,
            from_status=from_status, to_status=to_status,
            reason=reason, actor=actor,
        )
        self._s.add(evt)
        self._s.flush()
        return evt

    def transition_status(
        self, signal_id: uuid.UUID, to_status: str,
        reason: str | None = None, actor: str | None = None,
    ) -> Optional[Signal]:
        sig = self.get_by_id(signal_id)
        if sig is None:
            return None
        from_status = sig.status
        sig.status = to_status
        sig.updated_at = datetime.now(timezone.utc)
        self.add_lifecycle_event(
            signal_id=signal_id, event_type="status_transition",
            from_status=from_status, to_status=to_status,
            reason=reason, actor=actor,
        )
        self._s.flush()
        return sig
