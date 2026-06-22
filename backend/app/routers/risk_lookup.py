"""Lookup endpoints for the strategy workbench binding picker.

GET /api/risk-policy-versions  → list active risk_policy_versions + name
GET /api/capital-pools         → list capital_pools (optionally by pool_type)

Plan: docs/superpowers/plans/2026-06-18-strategy-workbench-canvas-first.md Task 22
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.domain.risk import CapitalPool, RiskPolicy, RiskPolicyVersion

router = APIRouter(prefix="/api", tags=["risk-lookup"])


class RiskPolicyVersionSummary(BaseModel):
    id: uuid.UUID
    risk_policy_id: uuid.UUID
    policy_name: str
    version_no: int
    status: str


class CapitalPoolSummary(BaseModel):
    id: uuid.UUID
    name: str
    pool_type: str
    currency: str
    total_budget: float
    max_position_pct_per_trade: float
    max_total_exposure_pct: float
    max_daily_loss_pct: float
    max_drawdown_pct: float


@router.get(
    "/risk-policy-versions",
    response_model=list[RiskPolicyVersionSummary],
)
def list_risk_policy_versions(
    status: str = Query(default="active"),
    db: Session = Depends(get_db),
):
    """List risk_policy_versions filtered by status (default active)."""
    rows = (
        db.query(RiskPolicyVersion, RiskPolicy)
        .join(RiskPolicy, RiskPolicy.id == RiskPolicyVersion.risk_policy_id)
        .filter(RiskPolicyVersion.status == status)
        .order_by(RiskPolicy.name, RiskPolicyVersion.version_no.desc())
        .all()
    )
    return [
        RiskPolicyVersionSummary(
            id=rpv.id,
            risk_policy_id=rpv.risk_policy_id,
            policy_name=rp.name,
            version_no=rpv.version_no,
            status=rpv.status,
        )
        for rpv, rp in rows
    ]


@router.get(
    "/capital-pools",
    response_model=list[CapitalPoolSummary],
)
def list_capital_pools(
    pool_type: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    """List capital pools, optionally filtered by pool_type (e.g. live_small)."""
    q = db.query(CapitalPool)
    if pool_type:
        q = q.filter(CapitalPool.pool_type == pool_type)
    rows = q.order_by(CapitalPool.name).all()
    return [
        CapitalPoolSummary(
            id=p.id,
            name=p.name,
            pool_type=p.pool_type,
            currency=p.currency,
            total_budget=float(p.total_budget),
            max_position_pct_per_trade=float(p.max_position_pct_per_trade),
            max_total_exposure_pct=float(p.max_total_exposure_pct),
            max_daily_loss_pct=float(p.max_daily_loss_pct),
            max_drawdown_pct=float(p.max_drawdown_pct),
        )
        for p in rows
    ]
