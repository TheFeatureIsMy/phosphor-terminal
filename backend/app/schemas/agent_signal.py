from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class AgentProfileCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    kind: str = "research"
    description: Optional[str] = None


class AgentProfileResponse(BaseModel):
    id: int
    name: str
    kind: str
    status: str
    description: Optional[str] = None
    last_heartbeat_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AgentSignalCreate(BaseModel):
    agent_id: int
    source: str = "manual"
    message_type: str = "research"
    symbol: str = Field(..., min_length=1, max_length=64)
    market: str = "stock"
    direction: Optional[str] = None
    rating: Optional[str] = None
    confidence: Optional[float] = None
    target_price: Optional[float] = None
    stop_loss: Optional[float] = None
    time_horizon: Optional[str] = None
    content: str = Field(..., min_length=1)
    evidence: dict[str, Any] = {}
    linked_research_run_id: Optional[int] = None
    linked_strategy_id: Optional[int] = None


class AgentSignalResponse(BaseModel):
    id: int
    agent_id: int
    source: str
    message_type: str
    symbol: str
    market: str
    direction: Optional[str] = None
    rating: Optional[str] = None
    confidence: Optional[float] = None
    target_price: Optional[float] = None
    stop_loss: Optional[float] = None
    time_horizon: Optional[str] = None
    content: str
    evidence: dict[str, Any] = {}
    linked_research_run_id: Optional[int] = None
    linked_strategy_id: Optional[int] = None
    overall_score: Optional[float] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
