"""FeatureSnapshot write/read service — captures indicator + structure + AI
context at the moment a trade decision is made."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.feature import FeatureSnapshot

logger = logging.getLogger(__name__)


class FeatureSnapshotService:
    """Thin service around the ``feature_snapshots`` table."""

    def __init__(self, db: Session):
        self._db = db

    # ------------------------------------------------------------------
    # Write
    # ------------------------------------------------------------------

    def create_snapshot(
        self,
        *,
        trade_intent_id: uuid.UUID | str | None = None,
        runtime_snapshot_id: str | None = None,
        strategy_id: str | None = None,
        strategy_version_id: uuid.UUID | str | None = None,
        symbol: str,
        exchange: str | None = None,
        timeframe: str | None = None,
        features: dict | None = None,
        structure_context: dict | None = None,
        mtf_guard_context: dict | None = None,
        ai_context: dict | None = None,
        risk_context: dict | None = None,
        liquidity_context: dict | None = None,
    ) -> FeatureSnapshot:
        """Persist a new FeatureSnapshot row and return it."""
        now = datetime.now(timezone.utc)

        # Parse UUIDs when passed as strings
        _trade_intent_id = (
            uuid.UUID(str(trade_intent_id)) if trade_intent_id else None
        )
        _strategy_version_id = (
            uuid.UUID(str(strategy_version_id)) if strategy_version_id else None
        )

        row = FeatureSnapshot(
            id=uuid.uuid4(),
            snapshot_at=now,
            symbol=symbol,
            exchange=exchange,
            timeframe=timeframe,
            strategy_id=strategy_id,
            strategy_version_id=_strategy_version_id,
            runtime_snapshot_id=runtime_snapshot_id,
            trade_intent_id=_trade_intent_id,
            # Indicator / feature payload
            technical_features=features,
            # Contextual payloads
            structure_context=structure_context,
            mtf_guard_context=mtf_guard_context,
            ai_context=ai_context,
            risk_context=risk_context,
            liquidity_context=liquidity_context,
        )
        try:
            self._db.add(row)
            self._db.flush()
            logger.info(
                "FeatureSnapshot %s created for snapshot=%s trade_intent=%s",
                row.id, runtime_snapshot_id, trade_intent_id,
            )
        except Exception:
            logger.exception(
                "Failed to persist FeatureSnapshot for snapshot=%s",
                runtime_snapshot_id,
            )
            raise
        return row

    # ------------------------------------------------------------------
    # Read
    # ------------------------------------------------------------------

    def get_by_trade(
        self, trade_intent_id: uuid.UUID | str,
    ) -> Optional[FeatureSnapshot]:
        """Look up the FeatureSnapshot linked to a trade intent."""
        uid = uuid.UUID(str(trade_intent_id))
        return (
            self._db.query(FeatureSnapshot)
            .filter(FeatureSnapshot.trade_intent_id == uid)
            .order_by(FeatureSnapshot.snapshot_at.desc())
            .first()
        )

    def get_by_snapshot(
        self, runtime_snapshot_id: str,
    ) -> Optional[FeatureSnapshot]:
        """Look up by the runtime decision snapshot ID string."""
        return (
            self._db.query(FeatureSnapshot)
            .filter(FeatureSnapshot.runtime_snapshot_id == runtime_snapshot_id)
            .order_by(FeatureSnapshot.snapshot_at.desc())
            .first()
        )
