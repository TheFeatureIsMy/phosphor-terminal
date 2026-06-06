"""Data Source Management BFF schemas"""
from __future__ import annotations
from pydantic import BaseModel, Field
from app.schemas.common import AvailableAction


class DataSourceResponse(BaseModel):
    source_id: str
    name: str
    category: str  # exchange_kline / orderbook / funding / open_interest / news / whale / on_chain / research / social
    provider: str = ""
    status: str = "active"  # active / inactive / error / rate_limited
    last_fetch: str = ""
    latency_ms: int = 0
    freshness: str = "fresh"  # fresh / stale / expired
    config: dict = Field(default_factory=dict)
    reason_codes: list[str] = Field(default_factory=list)


class DataSourceManagementResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    sources: list[DataSourceResponse] = Field(default_factory=list)
    total_active: int = 0
    total_error: int = 0
