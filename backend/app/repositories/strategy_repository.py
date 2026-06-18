"""Strategy Repository — Strategy/Version CRUD."""
import uuid
from typing import Optional

from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.domain.strategy import StrategyV2, StrategyVersion


class StrategyRepository:
    def __init__(self, session: Session):
        self._s = session

    def create_strategy(self, strategy: StrategyV2) -> StrategyV2:
        self._s.add(strategy)
        self._s.flush()
        return strategy

    def get_strategy_by_id(self, strategy_id: uuid.UUID) -> Optional[StrategyV2]:
        return self._s.get(StrategyV2, strategy_id)

    def list_strategies(
        self, *, status: str | None = None, offset: int = 0, limit: int = 50,
    ) -> list[StrategyV2]:
        stmt = select(StrategyV2)
        if status:
            stmt = stmt.where(StrategyV2.status == status)
        stmt = stmt.order_by(StrategyV2.updated_at.desc()).offset(offset).limit(limit)
        return list(self._s.scalars(stmt).all())

    def create_version(self, version: StrategyVersion) -> StrategyVersion:
        self._s.add(version)
        self._s.flush()
        return version

    def get_version_by_id(self, version_id: uuid.UUID) -> Optional[StrategyVersion]:
        return self._s.get(StrategyVersion, version_id)

    def get_latest_version(self, strategy_id: uuid.UUID) -> Optional[StrategyVersion]:
        stmt = (
            select(StrategyVersion)
            .where(StrategyVersion.strategy_id == strategy_id)
            .order_by(StrategyVersion.version_no.desc())
            .limit(1)
        )
        return self._s.scalar(stmt)

    def next_version_no(self, strategy_id: uuid.UUID) -> int:
        stmt = (
            select(func.coalesce(func.max(StrategyVersion.version_no), 0))
            .where(StrategyVersion.strategy_id == strategy_id)
        )
        return (self._s.scalar(stmt) or 0) + 1

    def update_strategy(self, strategy: StrategyV2) -> StrategyV2:
        self._s.flush()
        return strategy

    def list_versions(
        self,
        strategy_id: uuid.UUID,
        *,
        status: str | None = None,
        offset: int = 0,
        limit: int = 50,
    ) -> list[StrategyVersion]:
        stmt = (
            select(StrategyVersion)
            .where(StrategyVersion.strategy_id == strategy_id)
        )
        if status:
            stmt = stmt.where(StrategyVersion.status == status)
        stmt = stmt.order_by(StrategyVersion.version_no.desc()).offset(offset).limit(limit)
        return list(self._s.scalars(stmt).all())

    def get_version_by_strategy_and_id(
        self, strategy_id: uuid.UUID, version_id: uuid.UUID,
    ) -> Optional[StrategyVersion]:
        stmt = (
            select(StrategyVersion)
            .where(
                StrategyVersion.strategy_id == strategy_id,
                StrategyVersion.id == version_id,
            )
        )
        return self._s.scalar(stmt)

    def delete_strategy(self, strategy: StrategyV2) -> None:
        self._s.delete(strategy)
        self._s.flush()

    def clone_version_for(self, src_version: StrategyVersion, *, new_strategy_id: uuid.UUID, new_version_no: int, created_by: str) -> StrategyVersion:
        import copy
        from app.services.dsl_hasher import compute_dsl_hash
        new_dsl = copy.deepcopy(src_version.rule_dsl)
        return StrategyVersion(
            strategy_id=new_strategy_id,
            version_no=new_version_no,
            status="draft",
            dsl_version=src_version.dsl_version,
            rule_dsl=new_dsl,
            dsl_hash=compute_dsl_hash(new_dsl),
            created_by=created_by,
        )
