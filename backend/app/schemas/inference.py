"""Inference job and runtime state schemas."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class InferenceJobCreate(BaseModel):
    job_type: str = Field(..., min_length=1, max_length=64)
    model_name: str = Field(..., min_length=1, max_length=128)
    provider_id: uuid.UUID | None = None
    input_payload: dict[str, Any]
    timeout_sec: int = Field(default=300, ge=1, le=3600)


class InferenceJobView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    job_type: str
    model_name: str
    status: str
    submitted_at: datetime
    started_at: datetime | None = None
    completed_at: datetime | None = None
    error_message: str | None = None
    estimated_cost_usd: float | None = None
    actual_cost_usd: float | None = None


class RuntimeStateView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    model_name: str
    provider: str
    state: str
    gpu_memory_mb: int | None = None
    last_heartbeat_at: datetime | None = None
