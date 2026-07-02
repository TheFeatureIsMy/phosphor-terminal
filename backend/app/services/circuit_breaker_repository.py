"""Repository for CircuitBreakerEvent DB access."""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, update

from app.domain.circuit_breaker import CircuitBreakerEvent

logger = logging.getLogger(__name__)


class CircuitBreakerRepository:
    """Wraps DB queries for CircuitBreakerEvent records.

    Follows the same direct DB access pattern as the existing
    GET /api/risk/circuit-breakers route in risk_bff.py.
    """

    def __init__(self, db):
        self.db = db

    def get(self, event_id: str) -> Optional[CircuitBreakerEvent]:
        """Fetch a single CircuitBreakerEvent by its UUID string id."""
        try:
            uid = UUID(event_id)
        except ValueError:
            logger.warning("[CircuitBreakerRepository] invalid event_id: %s", event_id)
            return None
        stmt = select(CircuitBreakerEvent).where(CircuitBreakerEvent.id == uid)
        return self.db.scalars(stmt).first()

    def mark_resolved(self, event_id: str) -> bool:
        """Mark a CircuitBreakerEvent as resolved. Returns True if updated."""
        try:
            uid = UUID(event_id)
        except ValueError:
            return False
        stmt = (
            update(CircuitBreakerEvent)
            .where(CircuitBreakerEvent.id == uid)
            .values(resolved=True, resolved_at=datetime.now(timezone.utc))
        )
        result = self.db.execute(stmt)
        self.db.commit()
        return result.rowcount > 0
