"""Reconciliation event and connection state schemas."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict


class ReconciliationEventView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    strategy_run_id: uuid.UUID | None = None
    freqtrade_run_id: uuid.UUID | None = None
    status: str
    drift_summary: dict[str, Any] | None = None
    started_at: datetime
    completed_at: datetime | None = None


class ConnectionStateView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    freqtrade_run_id: uuid.UUID
    state: str
    rest_status: str | None = None
    websocket_status: str | None = None
    docker_status: str | None = None
    open_positions_count: int | None = None
    native_risk_ok: bool | None = None
    last_checked_at: datetime
