"""Structure BFF schemas"""
from __future__ import annotations
from pydantic import BaseModel, Field
from app.schemas.common import AvailableAction


class MatrixCell(BaseModel):
    zone_type: str
    status: str = "unknown"  # active / warning / violated / inactive
    current_strength: float = 0
    filled_ratio: float = 0
    temporary_violation: bool = False
    action: str = ""
    reason_codes: list[str] = Field(default_factory=list)


class MatrixRow(BaseModel):
    timeframe: str
    cells: dict[str, MatrixCell] = Field(default_factory=dict)


class StructureMatrixResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    symbol: str = ""
    base_timeframe: str = "5m"
    rows: list[MatrixRow] = Field(default_factory=list)


class ShadowWindow(BaseModel):
    timeframe: str
    zone_type: str
    status: str = "active"
    violation_type: str | None = None
    reason_codes: list[str] = Field(default_factory=list)


class ShadowWindowsResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    symbol: str = ""
    windows: list[ShadowWindow] = Field(default_factory=list)
