"""MCP (Model Context Protocol) status, audit, and token schemas."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class McpStatusView(BaseModel):
    enabled: bool
    bind_address: str
    connected_clients: int = 0
    uptime_seconds: int = 0
    last_request_at: datetime | None = None


class McpAuditLogView(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tool_name: str
    caller_token_hash: str
    response_status: int
    latency_ms: int | None = None
    created_at: datetime


class McpTokenRotateRequest(BaseModel):
    reason: str | None = None


class McpTokenRotateResponse(BaseModel):
    new_token: str
    expires_at: datetime | None = None
    old_token_revoked: bool = True
