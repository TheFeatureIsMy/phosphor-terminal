"""Strategy activity log writer + reader."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.activity_log import StrategyActivityLog


VALID_KINDS = {
    "version_created",
    "version_status_changed",
    "binding_added",
    "binding_removed",
    "run_started",
    "backtest_completed",
    "archived",
}

INVALID_KIND = "invalid activity kind"


class StrategyActivityService:
    def __init__(self, db: Session):
        self._db = db

    def record(
        self,
        strategy_id: uuid.UUID,
        kind: str,
        summary: str,
        *,
        actor: str | None = None,
        delta: dict | None = None,
        ref_kind: str | None = None,
        ref_id: uuid.UUID | None = None,
    ) -> StrategyActivityLog:
        if kind not in VALID_KINDS:
            raise ValueError(f"{INVALID_KIND}: {kind}")
        entry = StrategyActivityLog(
            strategy_id=strategy_id,
            kind=kind,
            summary=summary,
            occurred_at=datetime.now(timezone.utc),
            actor=actor,
            delta=delta,
            ref_kind=ref_kind,
            ref_id=ref_id,
        )
        self._db.add(entry)
        self._db.flush()
        return entry

    def list_recent(self, strategy_id: uuid.UUID, limit: int = 20) -> list[StrategyActivityLog]:
        stmt = (
            select(StrategyActivityLog)
            .where(StrategyActivityLog.strategy_id == strategy_id)
            .order_by(StrategyActivityLog.occurred_at.desc())
            .limit(limit)
        )
        return list(self._db.scalars(stmt).all())
