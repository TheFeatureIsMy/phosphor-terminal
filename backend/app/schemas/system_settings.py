"""Pydantic schemas for system settings."""
from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class SystemSettingView(BaseModel):
    """Read-side view of a system setting."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    key: str
    value: dict
    category: str
    updated_at: datetime
    updated_by: str | None = None


class SystemSettingUpsertRequest(BaseModel):
    """Body for PUT /api/admin/system-settings/{key}."""

    value: dict
    category: Literal["general", "risk", "privacy", "retention"]
    updated_by: str = Field(default="api")
