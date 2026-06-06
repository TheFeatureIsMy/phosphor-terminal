"""Execution Ledger Pydantic schemas."""
import uuid
from datetime import datetime
from typing import Optional, Any

from pydantic import BaseModel, Field


class LedgerEventCreate(BaseModel):
    event_type: str = Field(..., min_length=1)
    source_system: str = Field(..., min_length=1)
    source_event_id: Optional[str] = None
    normalized_payload: dict[str, Any] = Field(...)
    raw_payload: Optional[dict[str, Any]] = None
    event_time: Optional[datetime] = None
    strategy_run_id: Optional[uuid.UUID] = None
    freqtrade_run_id: Optional[uuid.UUID] = None
    command_id: Optional[uuid.UUID] = None
    trade_intent_id: Optional[uuid.UUID] = None
    risk_decision_id: Optional[uuid.UUID] = None
    symbol: Optional[str] = None
    sequence_no: Optional[int] = None
    correlation_id: Optional[uuid.UUID] = None
    causation_id: Optional[uuid.UUID] = None


class LedgerEventResponse(BaseModel):
    id: uuid.UUID
    event_time: datetime
    event_type: str
    source_system: str
    source_event_id: Optional[str] = None
    event_hash: str
    strategy_run_id: Optional[uuid.UUID] = None
    freqtrade_run_id: Optional[uuid.UUID] = None
    command_id: Optional[uuid.UUID] = None
    trade_intent_id: Optional[uuid.UUID] = None
    risk_decision_id: Optional[uuid.UUID] = None
    symbol: Optional[str] = None
    sequence_no: Optional[int] = None
    schema_version: str
    correlation_id: Optional[uuid.UUID] = None
    causation_id: Optional[uuid.UUID] = None
    raw_payload: Optional[dict[str, Any]] = None
    normalized_payload: dict[str, Any]
    ingested_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class LedgerEventListResponse(BaseModel):
    items: list[LedgerEventResponse]
    offset: int
    limit: int
    total: Optional[int] = None
