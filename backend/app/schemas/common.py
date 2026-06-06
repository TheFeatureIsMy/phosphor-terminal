from typing import Any, Optional
from pydantic import BaseModel


class PaginatedResponse(BaseModel):
    items: list[Any]
    total: int
    page: int
    page_size: int
    pages: int


class ErrorResponse(BaseModel):
    detail: str
    code: Optional[str] = None


# ── BFF Unified Response Schema ──────────────────────────────────────
"""统一 BFF Response Schema — 所有聚合 API 必须返回 state + reason_codes + available_actions"""


class AvailableAction(BaseModel):
    type: str
    enabled: bool = True
    label: str
    confirm_required: bool = False
    metadata: dict[str, Any] = {}


class ReasonCode(BaseModel):
    code: str
    message: str = ""
    severity: str = "info"  # info / warning / error / critical


class UnifiedState(BaseModel):
    """Unified state model for all BFF responses"""
    state: str  # healthy / warning / blocked / locked / running / stopped / failed / reconciling / stale / unknown
    reason_codes: list[str] = []
    available_actions: list[AvailableAction] = []
