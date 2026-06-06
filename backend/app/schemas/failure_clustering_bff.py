"""Failure Clustering BFF schemas"""
from __future__ import annotations
from pydantic import BaseModel, Field
from app.schemas.common import AvailableAction


class FailureClusterResponse(BaseModel):
    cluster_name: str
    label: str = ""
    trade_count: int = 0
    total_loss: float = 0
    avg_loss_pct: float = 0
    example_trade_ids: list[str] = Field(default_factory=list)
    suggested_fix: str = ""
    severity: str = "medium"  # low / medium / high / critical


class RegimeFailureCell(BaseModel):
    regime: str
    failure_type: str
    count: int = 0
    total_loss: float = 0


class FailureClusteringResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    total_loss_trades: int = 0
    total_loss_amount: float = 0
    clusters: list[FailureClusterResponse] = Field(default_factory=list)
    regime_matrix: list[RegimeFailureCell] = Field(default_factory=list)
    common_reject_reasons: list[dict] = Field(default_factory=list)
    labels: list[str] = Field(default_factory=list)
