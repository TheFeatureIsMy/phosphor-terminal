"""Strategy clone service: new Strategy(draft) + cloned latest version as v1(draft)."""
from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.domain.strategy import StrategyV2
from app.repositories.strategy_repository import StrategyRepository
from app.services.strategy_activity_service import StrategyActivityService


class StrategyDuplicateService:
    def __init__(self, db: Session, activity: StrategyActivityService):
        self._db = db
        self._activity = activity

    def duplicate(self, source_strategy_id: uuid.UUID, *, name: str | None = None, actor: str = "api") -> StrategyV2:
        repo = StrategyRepository(self._db)
        src = repo.get_strategy_by_id(source_strategy_id)
        if not src:
            raise ValueError(f"source strategy not found: {source_strategy_id}")

        latest = repo.get_latest_version(source_strategy_id)
        if not latest:
            raise ValueError(f"source strategy has no version: {source_strategy_id}")

        new = StrategyV2(
            name=name or f"{src.name} copy",
            description=src.description,
            strategy_type=src.strategy_type,
            source_type=src.source_type,
            status="draft",
        )
        repo.create_strategy(new)
        self._db.flush()

        cloned = repo.clone_version_for(latest, new_strategy_id=new.id, new_version_no=1, created_by=actor)
        repo.create_version(cloned)

        self._activity.record(
            new.id,
            "version_created",
            f"duplicated from {src.name}",
            actor=actor,
            delta={"source_strategy_id": str(src.id), "source_version_no": latest.version_no},
            ref_kind="version",
            ref_id=cloned.id,
        )
        return new
