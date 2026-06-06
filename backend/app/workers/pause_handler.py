"""PauseStrategyHandler — pause a running strategy run."""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.execution import StrategyRun
from app.domain.strategy import StrategyVersion
from app.domain.enums import StrategyVersionStatus
from app.services.strategy_transition import validate_transition, InvalidTransitionError
from app.workers.handlers import CommandHandler

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class PauseStrategyHandler(CommandHandler):
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload
        strategy_run_id = command.aggregate_id
        reason = payload.get("reason", "user_requested")

        run = session.get(StrategyRun, strategy_run_id) if strategy_run_id else None
        if run is None:
            raise RuntimeError(f"StrategyRun {strategy_run_id} not found")

        if run.status in ("stopped", "failed"):
            return {"strategy_run_id": str(run.id), "status": run.status, "already_stopped": True}

        run.status = "stopped"
        run.stopped_at = _utcnow()

        version = session.get(StrategyVersion, run.strategy_version_id)
        if version:
            from_status = StrategyVersionStatus(version.status)
            to_status = StrategyVersionStatus.PAUSED
            try:
                validate_transition(from_status, to_status)
                version.status = to_status.value
            except InvalidTransitionError:
                logger.warning("Cannot transition version %s from %s to paused", version.id, from_status.value)

        session.flush()
        return {
            "strategy_run_id": str(run.id),
            "status": "stopped",
            "reason": reason,
        }
