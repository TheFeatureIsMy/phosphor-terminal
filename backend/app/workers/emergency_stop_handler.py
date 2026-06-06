"""EmergencyStopHandler — halt all active runs, delegating to EmergencyStopService."""
from __future__ import annotations

import logging
import uuid as uuid_mod
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.services.emergency_stop_service import EmergencyStopService
from app.workers.handlers import CommandHandler

logger = logging.getLogger(__name__)


def _to_uuid(val: Any) -> uuid_mod.UUID:
    return val if isinstance(val, uuid_mod.UUID) else uuid_mod.UUID(str(val))


class EmergencyStopHandler(CommandHandler):
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload

        raw_strategy_run_id = payload.get("strategy_run_id")
        strategy_run_id = _to_uuid(raw_strategy_run_id) if raw_strategy_run_id else None
        reason = payload.get("reason", "emergency_stop")

        service = EmergencyStopService(session)
        result = service.stop(strategy_run_id=strategy_run_id, reason=reason)

        return result
