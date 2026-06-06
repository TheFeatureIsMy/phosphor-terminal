"""Emergency stop / resume schemas."""
from __future__ import annotations

import uuid
from typing import Optional

from pydantic import BaseModel, Field


class EmergencyStopRequest(BaseModel):
    strategy_run_id: uuid.UUID | None = None  # None = stop all
    reason: str = "manual_emergency_stop"
    force_exit_positions: bool = False


class EmergencyStopResponse(BaseModel):
    stopped_runs: list[uuid.UUID]
    ledger_event_ids: list[uuid.UUID]
    message: str


class EmergencyResumeRequest(BaseModel):
    strategy_run_id: uuid.UUID
    reason: str | None = None
