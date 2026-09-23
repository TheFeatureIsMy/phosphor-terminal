"""ResumeStrategyHandler — resume a paused/stopped strategy run."""
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


class ResumeStrategyHandler(CommandHandler):
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        strategy_run_id = command.aggregate_id
        reason = (command.payload or {}).get("reason", "user_requested")

        run = session.get(StrategyRun, strategy_run_id) if strategy_run_id else None
        if run is None:
            raise RuntimeError(f"StrategyRun {strategy_run_id} not found")

        if run.status in ("running", "starting", "created"):
            return {"strategy_run_id": str(run.id), "status": run.status, "already_running": True}

        run.status = "running"
        run.started_at = _utcnow()
        run.stopped_at = None

        version = session.get(StrategyVersion, run.strategy_version_id)
        if version:
            from_status = StrategyVersionStatus(version.status)
            to_status = StrategyVersionStatus.PAPER_RUNNING
            try:
                validate_transition(from_status, to_status)
                version.status = to_status.value
            except InvalidTransitionError:
                logger.warning(
                    "Cannot transition version %s from %s to paper_running",
                    version.id, from_status.value,
                )

        session.flush()
        return {
            "strategy_run_id": str(run.id),
            "status": "running",
            "reason": reason,
        }
