"""RequestLiveSmallHandler — validate preconditions and create pending live_small run."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.execution import StrategyRun
from app.domain.strategy import StrategyVersion
from app.domain.enums import StrategyVersionStatus, StrategyRunMode
from app.services.strategy_transition import validate_transition, InvalidTransitionError
from app.workers.handlers import CommandHandler

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _to_uuid(val: Any) -> uuid.UUID:
    return val if isinstance(val, uuid.UUID) else uuid.UUID(str(val))


class RequestLiveSmallHandler(CommandHandler):
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload
        strategy_version_id = _to_uuid(payload["strategy_version_id"])
        capital_pool_id = payload.get("capital_pool_id")

        version = session.get(StrategyVersion, strategy_version_id)
        if version is None:
            raise RuntimeError(f"StrategyVersion {strategy_version_id} not found")

        from_status = StrategyVersionStatus(version.status)
        if from_status != StrategyVersionStatus.LIVE_PENDING:
            raise RuntimeError(
                f"Version must be in live_pending to request live_small, got {from_status.value}"
            )

        try:
            validate_transition(from_status, StrategyVersionStatus.LIVE_SMALL)
        except InvalidTransitionError as e:
            raise RuntimeError(str(e))

        run = StrategyRun(
            strategy_version_id=version.id,
            capital_pool_id=_to_uuid(capital_pool_id) if capital_pool_id else None,
            mode=StrategyRunMode.LIVE_SMALL.value,
            status="created",
        )
        session.add(run)
        session.flush()

        version.status = StrategyVersionStatus.LIVE_SMALL.value
        session.flush()

        return {
            "strategy_run_id": str(run.id),
            "strategy_version_id": str(version.id),
            "mode": "live_small",
            "status": "created",
        }
