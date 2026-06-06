"""Command Bus Pydantic schemas."""
import uuid
from datetime import datetime
from typing import Optional, Any

from pydantic import BaseModel, Field


class CommandCreate(BaseModel):
    command_type: str = Field(..., min_length=1)
    aggregate_type: str = Field(..., min_length=1)
    aggregate_id: Optional[uuid.UUID] = None
    payload: dict[str, Any] = Field(default_factory=dict)
    idempotency_key: str = Field(..., min_length=1)
    requested_by: str = Field(default="api")
    priority: int = Field(default=100, ge=1, le=1000)
    max_retries: int = Field(default=3, ge=0, le=10)
    timeout_sec: int = Field(default=300, ge=10, le=3600)
    correlation_id: Optional[uuid.UUID] = None


class CommandResponse(BaseModel):
    id: uuid.UUID
    command_type: str
    aggregate_type: str
    aggregate_id: Optional[uuid.UUID] = None
    status: str
    idempotency_key: str
    requested_by: str
    retry_count: int
    max_retries: int
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    cancel_requested: bool
    created_at: Optional[datetime] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class CommandCancelResponse(BaseModel):
    success: bool
    reason: str
