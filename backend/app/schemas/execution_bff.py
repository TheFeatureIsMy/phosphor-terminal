"""Execution BFF schemas"""
from __future__ import annotations
from datetime import datetime
from pydantic import BaseModel, Field
from app.schemas.common import AvailableAction


class ExecutionSession(BaseModel):
    run_id: str
    strategy_name: str = ""
    mode: str = ""  # dryrun / paper / live_small / live
    status: str = "stopped"
    symbol: str = ""
    open_positions: int = 0
    pending_orders: int = 0
    started_at: datetime | None = None
    last_heartbeat: datetime | None = None
    reason_codes: list[str] = Field(default_factory=list)


class ExecutionCenterResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    sessions: list[ExecutionSession] = Field(default_factory=list)
    total_running: int = 0
    total_open_positions: int = 0
    total_pending_orders: int = 0
    freqtrade_heartbeat: str = "unknown"
    execution_latency_ms: int = 0


class OrderResponse(BaseModel):
    id: str
    symbol: str
    side: str
    type: str
    quantity: float = 0
    price: float | None = None
    status: str = "pending"
    exchange_order_id: str | None = None
    freqtrade_trade_id: str | None = None
    created_at: datetime | None = None
    reason_codes: list[str] = Field(default_factory=list)


class PositionResponse(BaseModel):
    id: str
    symbol: str
    side: str
    avg_entry_price: float = 0
    current_price: float = 0
    quantity: float = 0
    unrealized_pnl: float = 0
    unrealized_pnl_pct: float = 0
    stop_loss: float | None = None
    take_profit: float | None = None
    state_difference: str | None = None
    reason_codes: list[str] = Field(default_factory=list)


class OrdersPositionsResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    orders: list[OrderResponse] = Field(default_factory=list)
    positions: list[PositionResponse] = Field(default_factory=list)


class CancelResponse(BaseModel):
    cancelled_order_id: str
    status: str
    reason_codes: list[str] = []


class ReconciliationRun(BaseModel):
    id: str
    status: str = "pending"
    started_at: datetime | None = None
    completed_at: datetime | None = None
    discrepancies: int = 0
    reason_codes: list[str] = Field(default_factory=list)


class CommandBusEvent(BaseModel):
    id: str
    command_type: str
    status: str
    created_at: datetime | None = None
    completed_at: datetime | None = None


class ReconciliationBusResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    recent_commands: list[CommandBusEvent] = Field(default_factory=list)
    reconciliation_runs: list[ReconciliationRun] = Field(default_factory=list)
    active_leases: list[dict] = Field(default_factory=list)
