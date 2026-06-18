"""Strategy workspace — BFF aggregation schemas for the workbench page.

Spec: docs/superpowers/specs/2026-06-17-strategy-workbench-canvas-first-design.md §6.1.A
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field, model_validator

from app.schemas.per_strategy_readiness import PerStrategyReadinessResponse
from app.schemas.strategy_binding import StrategyBindingResponse
from app.schemas.strategy_v2 import StrategyV2Response, StrategyVersionResponse


class ActivityEntryRef(BaseModel):
    kind: str
    id: uuid.UUID


class ActivityEntry(BaseModel):
    id: uuid.UUID
    kind: str
    occurred_at: datetime
    actor: Optional[str] = None
    summary: str
    delta: Optional[dict] = None
    ref: Optional[ActivityEntryRef] = None

    @model_validator(mode='before')
    @classmethod
    def _nest_ref(cls, data: Any) -> Any:
        if isinstance(data, dict):
            return data
        ref = None
        if getattr(data, 'ref_kind', None) and getattr(data, 'ref_id', None):
            ref = {'kind': data.ref_kind, 'id': data.ref_id}
        return {
            'id': data.id,
            'kind': data.kind,
            'occurred_at': data.occurred_at,
            'actor': data.actor,
            'summary': data.summary,
            'delta': data.delta,
            'ref': ref,
        }


class BacktestRunSummary(BaseModel):
    """Lightweight backtest run summary — not the full BacktestRun row."""
    id: int
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    status: str
    total_return: Optional[float] = None
    win_rate: Optional[float] = None
    max_drawdown: Optional[float] = None
    sharpe_ratio: Optional[float] = None

    model_config = {"from_attributes": True}


class StrategyRunSummary(BaseModel):
    """Lightweight strategy run summary — for dry_run / paper mode runs."""
    id: uuid.UUID
    mode: str
    status: str
    started_at: Optional[datetime] = None
    stopped_at: Optional[datetime] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class SignalLogicSummary(BaseModel):
    entry_text: str = ""
    exit_text: str = ""
    filter_count: int = 0


class DataDependencies(BaseModel):
    symbols: list[str] = Field(default_factory=list)
    timeframes: list[str] = Field(default_factory=list)
    indicators: list[str] = Field(default_factory=list)
    signal_sources: list[str] = Field(default_factory=list)


class WorkspaceSnapshotResponse(BaseModel):
    """Full BFF response for the strategy workbench (11 fields)."""
    strategy: StrategyV2Response
    versions: list[StrategyVersionResponse] = Field(default_factory=list)
    latest_version_id: Optional[uuid.UUID] = None
    bindings: list[StrategyBindingResponse] = Field(default_factory=list)
    recent_backtests: list[BacktestRunSummary] = Field(default_factory=list)
    recent_dryruns: list[StrategyRunSummary] = Field(default_factory=list)
    readiness: PerStrategyReadinessResponse
    activity: list[ActivityEntry] = Field(default_factory=list)
    signal_logic_summary: SignalLogicSummary = Field(default_factory=SignalLogicSummary)
    data_dependencies: DataDependencies = Field(default_factory=DataDependencies)
