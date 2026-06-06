"""Strategy v2.5 schemas — StrategyV2 + StrategyVersion + DSL validation."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class CreateStrategyRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=128)
    description: Optional[str] = None
    strategy_type: str = Field(default="rule_dsl", max_length=64)
    source_type: str = Field(default="manual", max_length=64)


class StrategyV2Response(BaseModel):
    id: uuid.UUID
    name: str
    description: Optional[str] = None
    strategy_type: str
    source_type: str
    status: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class CreateVersionRequest(BaseModel):
    rule_dsl: dict[str, Any] = Field(..., description="Complete StrategyRuleDSL RulePackage")
    created_by: str = Field(default="user")


class StrategyVersionResponse(BaseModel):
    id: uuid.UUID
    strategy_id: uuid.UUID
    version_no: int
    status: str
    dsl_version: str
    rule_dsl: dict[str, Any]
    dsl_hash: str
    created_by: str
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class ValidateDSLRequest(BaseModel):
    dsl: dict[str, Any] = Field(..., description="DSL to validate")


class DSLErrorResponse(BaseModel):
    code: str
    path: str
    message: str
    severity: str = "error"


class DSLValidationResponse(BaseModel):
    valid: bool
    error_count: int = 0
    warning_count: int = 0
    safe_hold_required: bool = False
    safe_hold_reasons: list[str] = []
    errors: list[DSLErrorResponse] = []
    warnings: list[DSLErrorResponse] = []


class UpdateStrategyRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=128)
    description: Optional[str] = None
    status: Optional[str] = Field(None, max_length=16)


class TransitionVersionStatusRequest(BaseModel):
    to_status: str = Field(..., description="Target StrategyVersionStatus value")
    reason: Optional[str] = Field(None, max_length=512)


class VersionDiffResponse(BaseModel):
    from_version_no: int
    to_version_no: int
    added: dict[str, Any] = {}
    removed: dict[str, Any] = {}
    changed: dict[str, Any] = {}
    unchanged_keys: list[str] = []
