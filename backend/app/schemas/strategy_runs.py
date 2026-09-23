"""Strategy run and Freqtrade run schemas."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict


class StrategyRunView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    strategy_version_id: uuid.UUID
    mode: str
    status: str
    started_at: datetime | None = None
    stopped_at: datetime | None = None
    created_at: datetime


class RunExecutionSummary(BaseModel):
    """Aggregated execution facts for a run (orders / positions / activity)."""

    orders_total: int = 0
    orders_open: int = 0
    orders_pending: int = 0
    positions_open: int = 0
    last_ledger_event_at: datetime | None = None


class StrategyRunDetail(StrategyRunView):
    config_snapshot: dict[str, Any] | None = None
    result_summary: dict[str, Any] | None = None
    execution: RunExecutionSummary = RunExecutionSummary()


class FreqtradeRunView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    strategy_run_id: uuid.UUID
    container_name: str | None = None
    status: str
    heartbeat_at: datetime | None = None
    config_path: str | None = None
    rules_path: str | None = None
