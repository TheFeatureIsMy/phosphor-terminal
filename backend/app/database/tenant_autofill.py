"""Generic tenant backfill for ORM inserts.

Models that carry ``tenant_id`` but derive ownership from a strategy / version /
run get the value filled from their parent before the INSERT. Model-specific
hooks can still run afterwards and are idempotent.
"""
from __future__ import annotations

import uuid

from sqlalchemy import event, select
from sqlalchemy.orm import Session


@event.listens_for(Session, "before_flush")
def _fill_tenant_ids(session: Session, flush_context, instances) -> None:
    pending = [
        obj for obj in session.new
        if getattr(obj, "tenant_id", None) is None and hasattr(obj, "tenant_id")
    ]
    if not pending:
        return

    from app.domain.execution import StrategyRun
    from app.domain.strategy import StrategyV2, StrategyVersion

    connection = session.connection()
    run_cache: dict[uuid.UUID, int | None] = {}
    version_cache: dict[uuid.UUID, int | None] = {}
    strategy_cache: dict[uuid.UUID, int | None] = {}

    def as_uuid(value):
        if isinstance(value, uuid.UUID):
            return value
        if isinstance(value, str):
            try:
                return uuid.UUID(value)
            except ValueError:
                return None
        return None

    def run_tenant(run_id):
        if run_id not in run_cache:
            run_cache[run_id] = connection.execute(
                select(StrategyRun.tenant_id).where(StrategyRun.id == run_id)
            ).scalar()
        return run_cache[run_id]

    def version_tenant(version_id):
        if version_id not in version_cache:
            version_cache[version_id] = connection.execute(
                select(StrategyVersion.tenant_id).where(
                    StrategyVersion.id == version_id
                )
            ).scalar()
        return version_cache[version_id]

    def strategy_tenant(strategy_id):
        if strategy_id not in strategy_cache:
            strategy_cache[strategy_id] = connection.execute(
                select(StrategyV2.tenant_id).where(StrategyV2.id == strategy_id)
            ).scalar()
        return strategy_cache[strategy_id]

    for obj in pending:
        run_id = getattr(obj, "strategy_run_id", None)
        version_id = getattr(obj, "strategy_version_id", None)
        strategy_id = getattr(obj, "strategy_id", None)
        tenant_id = None
        run_uuid = as_uuid(run_id)
        version_uuid = as_uuid(version_id)
        strategy_uuid = as_uuid(strategy_id)
        if run_uuid is not None:
            tenant_id = run_tenant(run_uuid)
        if tenant_id is None and version_uuid is not None:
            tenant_id = version_tenant(version_uuid)
        if tenant_id is None and strategy_uuid is not None:
            tenant_id = strategy_tenant(strategy_uuid)
        obj.tenant_id = tenant_id
