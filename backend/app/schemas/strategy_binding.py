"""StrategyBinding API schemas — Pydantic request/response models."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel


class RiskPolicySummary(BaseModel):
    id: uuid.UUID
    name: str
    version_no: int
    policy_json_summary: dict[str, Any]

    model_config = {"from_attributes": True}


class CapitalPoolSummary(BaseModel):
    id: uuid.UUID
    name: str
    pool_type: str
    total_budget: float
    currency: str
    remaining_budget: float

    model_config = {"from_attributes": True}


class StrategyBindingResponse(BaseModel):
    id: uuid.UUID
    strategy_version_id: uuid.UUID
    version_no: int
    risk_policy: RiskPolicySummary
    capital_pool: CapitalPoolSummary
    mode: str
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class CreateBindingRequest(BaseModel):
    strategy_version_id: uuid.UUID
    risk_policy_version_id: uuid.UUID
    capital_pool_id: uuid.UUID
    mode: str   # backtest | dry_run | shadow | live_small
