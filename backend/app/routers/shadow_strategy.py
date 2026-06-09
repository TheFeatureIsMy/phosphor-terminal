"""Shadow Strategy API — generate, validate, backtest, and upgrade shadow
strategy drafts from failure clusters.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.shadow_strategy_generator import ShadowStrategyGeneratorService
from app.services.shadow_strategy_validation import ShadowStrategyValidationService
from app.services.strategy_upgrade import StrategyUpgradeService


router = APIRouter(tags=["shadow-strategy"])

_generator = ShadowStrategyGeneratorService()
_validation = ShadowStrategyValidationService()
_upgrade = StrategyUpgradeService()


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------

class ShadowStrategyDraftResponse(BaseModel):
    id: uuid.UUID
    source_type: str
    source_failure_cluster_id: uuid.UUID | None = None
    target_strategy_id: uuid.UUID
    target_strategy_version_id: uuid.UUID
    title: str
    summary: str | None = None
    status: str
    failure_pattern: dict | None = None
    dsl_patch: list[dict] | dict = Field(default_factory=list)
    validation_state: dict = Field(default_factory=dict)
    backtest_id: uuid.UUID | None = None
    dryrun_id: uuid.UUID | None = None
    created_by: str = "growth_engine"
    created_at: str | None = None
    updated_at: str | None = None

    model_config = {"from_attributes": True}


class ValidationResponse(BaseModel):
    valid: bool
    error_count: int = 0
    warning_count: int = 0
    safe_hold_required: bool = False
    safe_hold_reasons: list[str] = Field(default_factory=list)
    errors: list[dict] = Field(default_factory=list)
    warnings: list[dict] = Field(default_factory=list)
    patched_dsl_hash: str = ""
    validated_at: str | None = None


class BacktestResponse(BaseModel):
    draft_id: str
    backtest_command_id: str
    command_created: bool
    command_status: str
    idempotency_key: str


class UpgradeRequestResponse(BaseModel):
    id: uuid.UUID
    strategy_id: uuid.UUID
    from_version_id: uuid.UUID
    shadow_strategy_draft_id: uuid.UUID | None = None
    proposed_version_name: str | None = None
    diff_summary: str | None = None
    validation_report: dict | None = None
    approval_status: str
    approved_by: str | None = None
    approved_at: str | None = None
    created_at: str | None = None

    model_config = {"from_attributes": True}


class ApproveRequest(BaseModel):
    approved_by: str


class RejectRequest(BaseModel):
    reason: str


class VersionResponse(BaseModel):
    id: uuid.UUID
    strategy_id: uuid.UUID
    version_no: int
    status: str
    dsl_version: str
    dsl_hash: str
    created_by: str
    created_at: str | None = None

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Shadow Strategy Draft endpoints
# ---------------------------------------------------------------------------

@router.post(
    "/api/growth/failure-clusters/{cluster_id}/generate-shadow-strategy",
    response_model=ShadowStrategyDraftResponse,
    status_code=201,
    tags=["shadow-strategy"],
)
def generate_shadow_strategy(
    cluster_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """Generate a shadow strategy draft from a failure cluster."""
    try:
        draft = _generator.generate_from_cluster(db, cluster_id)
        db.commit()
        db.refresh(draft)
        return ShadowStrategyDraftResponse.model_validate(draft)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get(
    "/api/shadow-strategies",
    response_model=list[ShadowStrategyDraftResponse],
    tags=["shadow-strategy"],
)
def list_shadow_strategies(
    strategy_id: uuid.UUID | None = Query(None, description="Filter by target strategy"),
    status: str | None = Query(None, description="Filter by status"),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """List shadow strategy drafts with optional filters."""
    drafts = _generator.list_drafts(
        db, strategy_id=strategy_id, status=status, offset=offset, limit=limit,
    )
    return [ShadowStrategyDraftResponse.model_validate(d) for d in drafts]


@router.get(
    "/api/shadow-strategies/{shadow_strategy_id}",
    response_model=ShadowStrategyDraftResponse,
    tags=["shadow-strategy"],
)
def get_shadow_strategy(
    shadow_strategy_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """Get a single shadow strategy draft by ID."""
    draft = _generator.get_draft(db, shadow_strategy_id)
    if draft is None:
        raise HTTPException(status_code=404, detail="Shadow strategy draft not found")
    return ShadowStrategyDraftResponse.model_validate(draft)


@router.post(
    "/api/shadow-strategies/{shadow_strategy_id}/validate",
    response_model=ValidationResponse,
    tags=["shadow-strategy"],
)
def validate_shadow_strategy(
    shadow_strategy_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """Run static DSL validation on a shadow strategy draft."""
    try:
        result = _validation.validate(db, shadow_strategy_id)
        db.commit()
        return ValidationResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/api/shadow-strategies/{shadow_strategy_id}/backtest",
    response_model=BacktestResponse,
    tags=["shadow-strategy"],
)
def backtest_shadow_strategy(
    shadow_strategy_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """Enqueue an incremental backtest for a shadow strategy draft."""
    try:
        result = _validation.run_incremental_backtest(db, shadow_strategy_id)
        db.commit()
        return BacktestResponse(**result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/api/shadow-strategies/{shadow_strategy_id}/request-upgrade",
    response_model=UpgradeRequestResponse,
    status_code=201,
    tags=["shadow-strategy"],
)
def request_upgrade(
    shadow_strategy_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """Request an upgrade from shadow strategy to a new strategy version."""
    try:
        req = _upgrade.request_upgrade(db, shadow_strategy_id)
        db.commit()
        db.refresh(req)
        return UpgradeRequestResponse.model_validate(req)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ---------------------------------------------------------------------------
# Upgrade Request endpoints (under strategies_v2 prefix)
# ---------------------------------------------------------------------------

@router.get(
    "/api/v2/strategies/{strategy_id}/upgrade-requests",
    response_model=list[UpgradeRequestResponse],
    tags=["strategies-v2", "shadow-strategy"],
)
def list_upgrade_requests(
    strategy_id: uuid.UUID,
    status: str | None = Query(None, description="Filter by approval_status"),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """List upgrade requests for a strategy."""
    requests = _upgrade.list_requests(
        db, strategy_id, status=status, offset=offset, limit=limit,
    )
    return [UpgradeRequestResponse.model_validate(r) for r in requests]


@router.post(
    "/api/v2/strategies/{strategy_id}/upgrade-requests/{request_id}/approve",
    response_model=VersionResponse,
    tags=["strategies-v2", "shadow-strategy"],
)
def approve_upgrade_request(
    strategy_id: uuid.UUID,
    request_id: uuid.UUID,
    body: ApproveRequest,
    db: Session = Depends(get_db),
):
    """Approve an upgrade request — creates a new StrategyVersion."""
    # Verify request belongs to this strategy
    req = _upgrade.get_request(db, request_id)
    if req is None:
        raise HTTPException(status_code=404, detail="Upgrade request not found")
    if req.strategy_id != strategy_id:
        raise HTTPException(status_code=404, detail="Upgrade request not found for this strategy")

    try:
        version = _upgrade.approve(db, request_id, body.approved_by)
        db.commit()
        db.refresh(version)
        return VersionResponse.model_validate(version)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/api/v2/strategies/{strategy_id}/upgrade-requests/{request_id}/reject",
    response_model=UpgradeRequestResponse,
    tags=["strategies-v2", "shadow-strategy"],
)
def reject_upgrade_request(
    strategy_id: uuid.UUID,
    request_id: uuid.UUID,
    body: RejectRequest,
    db: Session = Depends(get_db),
):
    """Reject an upgrade request."""
    req = _upgrade.get_request(db, request_id)
    if req is None:
        raise HTTPException(status_code=404, detail="Upgrade request not found")
    if req.strategy_id != strategy_id:
        raise HTTPException(status_code=404, detail="Upgrade request not found for this strategy")

    try:
        updated = _upgrade.reject(db, request_id, body.reason)
        db.commit()
        db.refresh(updated)
        return UpgradeRequestResponse.model_validate(updated)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
