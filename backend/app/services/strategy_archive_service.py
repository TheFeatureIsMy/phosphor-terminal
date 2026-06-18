"""Strategy archive service — admin force-archive of strategy + all non-archived versions."""
from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.domain.strategy import StrategyV2
from app.repositories.strategy_repository import StrategyRepository
from app.services.strategy_activity_service import StrategyActivityService


class StrategyArchiveService:
    def __init__(self, db: Session, activity: StrategyActivityService):
        self._db = db
        self._activity = activity

    def archive(self, strategy_id: uuid.UUID, *, reason: str | None = None, actor: str = "api") -> StrategyV2:
        repo = StrategyRepository(self._db)
        strategy = repo.get_strategy_by_id(strategy_id)
        if not strategy:
            raise ValueError(f"strategy not found: {strategy_id}")

        versions = repo.list_versions(strategy_id)
        archived_count = 0
        for v in versions:
            if v.status != "archived":
                v.status = "archived"
                archived_count += 1

        if strategy.status != "archived":
            strategy.status = "archived"

        self._db.flush()

        self._activity.record(
            strategy_id,
            "archived",
            f"archived: {reason}" if reason else "archived",
            actor=actor,
            delta={"version_count": archived_count, "reason": reason},
        )
        return strategy
