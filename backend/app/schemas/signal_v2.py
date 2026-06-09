"""Signal v2 schemas — create, view, aggregation, conflict checks."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


class SignalCreate(BaseModel):
    source_type: str = Field(..., min_length=1, max_length=64)
    symbol: str = Field(..., min_length=1, max_length=32)
    direction: str = Field(..., min_length=1, max_length=16)
    confidence: float = Field(..., ge=0.0, le=1.0)
    score: float | None = Field(default=None, ge=0.0, le=5.0)
    risk_level: str = Field(default="medium", max_length=16)
    expires_at: datetime
    reasoning: str = Field(..., min_length=1)
    can_live_trade: bool = False
    trigger_condition: dict[str, Any] | None = None
    current_state: dict[str, Any] | None = None
    structured_output: dict[str, Any] | None = None
    raw_output: str | None = None
    evidence: list[dict[str, Any]] | None = None
    provider_trace: dict[str, Any] | None = None

    @field_validator("direction")
    @classmethod
    def validate_direction(cls, v: str) -> str:
        allowed = {"long", "short", "hold"}
        if v not in allowed:
            raise ValueError(f"direction must be one of {allowed}")
        return v

    @field_validator("risk_level")
    @classmethod
    def validate_risk_level(cls, v: str) -> str:
        allowed = {"low", "medium", "high", "extreme"}
        if v not in allowed:
            raise ValueError(f"risk_level must be one of {allowed}")
        return v


class SignalSummary(BaseModel):
    """Lightweight signal list item."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    source_type: str
    symbol: str
    direction: str
    confidence: float
    score: float | None = None
    risk_level: str
    status: str
    expires_at: datetime
    created_at: datetime


class SignalView(SignalSummary):
    """Full signal detail view."""

    reasoning: str | None = None
    can_live_trade: bool
    trigger_condition: dict[str, Any] | None = None
    current_state: dict[str, Any] | None = None
    evidence: list[dict[str, Any]] | None = None
    lifecycle_events: list[dict[str, Any]] | None = None
    provider_trace: dict[str, Any] | None = None


class SignalPayloadView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    signal_id: uuid.UUID
    reasoning: str | None = None
    structured_output: dict[str, Any] | None = None
    raw_output: str | None = None
    trigger_condition: dict[str, Any] | None = None
    current_state: dict[str, Any] | None = None


class SignalEvidenceView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    signal_id: uuid.UUID
    evidence_type: str
    content: dict[str, Any]
    created_at: datetime


class SignalTransitionRequest(BaseModel):
    target_status: str = Field(..., min_length=1, max_length=32)
    reason: str | None = None


class SignalConflictCheckRequest(BaseModel):
    symbol: str = Field(..., min_length=1, max_length=32)
    direction: str = Field(..., min_length=1, max_length=16)


class SignalConflictCheckResponse(BaseModel):
    has_conflict: bool
    conflicting_signals: list[SignalSummary] = []


class SignalAggregateRequest(BaseModel):
    symbols: list[str] | None = None
    group_by: str = Field(default="symbol", max_length=32)

    @field_validator("group_by")
    @classmethod
    def validate_group_by(cls, v: str) -> str:
        allowed = {"symbol", "source_type", "direction"}
        if v not in allowed:
            raise ValueError(f"group_by must be one of {allowed}")
        return v


class SignalAggregateResponse(BaseModel):
    groups: list[dict[str, Any]]
    total_count: int


class SignalNextAction(BaseModel):
    type: str
    enabled: bool = True
    label: str


class SignalDetailWithActions(SignalView):
    next_actions: list[SignalNextAction] = []
