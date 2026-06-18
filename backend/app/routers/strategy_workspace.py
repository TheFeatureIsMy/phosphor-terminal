"""Strategy workspace router — 7 endpoints for the strategy workbench.

Spec: docs/superpowers/specs/2026-06-17-strategy-workbench-canvas-first-design.md §6.1 A–G
"""
from __future__ import annotations

import uuid
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.repositories.strategy_repository import StrategyRepository
from app.schemas.strategy_binding import (
    CreateBindingRequest,
    StrategyBindingResponse,
)
from app.schemas.strategy_v2 import StrategyV2Response
from app.schemas.strategy_workspace import ActivityEntry, WorkspaceSnapshotResponse
from app.services.strategy_activity_service import StrategyActivityService
from app.services.strategy_archive_service import StrategyArchiveService
from app.services.strategy_binding_errors import (
    BindingInUseError,
    DuplicateBindingError,
    PolicyArchivedError,
    PoolMismatchError,
)
from app.services.strategy_binding_service import StrategyBindingService
from app.services.strategy_duplicate_service import StrategyDuplicateService
from app.services.strategy_workspace_aggregator import StrategyWorkspaceAggregator

router = APIRouter(prefix="/api/v2/strategies", tags=["strategy-workspace"])


# ── Request body schemas ────────────────────────────────────────────────


class DuplicateRequest(BaseModel):
    name: Optional[str] = None


class ArchiveRequest(BaseModel):
    reason: Optional[str] = None


# ── Error mapping helpers ────────────────────────────────────────────────

_ERROR_CODE_TO_STATUS = {
    "BINDING_DUPLICATE": 409,
    "BINDING_POOL_MISMATCH": 422,
    "BINDING_POLICY_ARCHIVED": 422,
    "BINDING_IN_USE": 409,
}


def _raise_service_error(err: Exception) -> None:
    """Map service exceptions to HTTP errors per spec §6.1."""
    code = getattr(err, "code", None)
    if code and code in _ERROR_CODE_TO_STATUS:
        status = _ERROR_CODE_TO_STATUS[code]
        raise HTTPException(
            status_code=status,
            detail={"code": code, "message": str(err)},
        )
    if isinstance(err, ValueError):
        if "not found" in str(err):
            raise HTTPException(status_code=404, detail=str(err))
        raise HTTPException(status_code=422, detail=str(err))
    raise HTTPException(status_code=500, detail=str(err))


def _check_strategy_exists(db: Session, strategy_id: uuid.UUID) -> None:
    """Raise 404 if the strategy does not exist."""
    repo = StrategyRepository(db)
    if not repo.get_strategy_by_id(strategy_id):
        raise HTTPException(status_code=404, detail="Strategy not found")


# ── Binding response builder (mirrors aggregator._build_binding_responses) ──


def _build_binding_responses(
    db: Session,
    raw_bindings: list[Any],
) -> list[StrategyBindingResponse]:
    """Build StrategyBindingResponse list with full risk_policy + capital_pool summaries."""
    from app.domain.risk import CapitalPool, RiskPolicy, RiskPolicyVersion
    from app.domain.strategy import StrategyVersion

    results: list[StrategyBindingResponse] = []
    for b in raw_bindings:
        version = (
            db.query(StrategyVersion)
            .filter(StrategyVersion.id == b.strategy_version_id)
            .first()
        )
        rpv = (
            db.query(RiskPolicyVersion)
            .filter(RiskPolicyVersion.id == b.risk_policy_version_id)
            .first()
        )
        rp_name = ""
        rp_policy_json: dict[str, Any] = {}
        if rpv:
            rp = (
                db.query(RiskPolicy)
                .filter(RiskPolicy.id == rpv.risk_policy_id)
                .first()
            )
            if rp:
                rp_name = rp.name
            rp_policy_json = rpv.policy_json

        pool = (
            db.query(CapitalPool)
            .filter(CapitalPool.id == b.capital_pool_id)
            .first()
        )

        results.append(
            StrategyBindingResponse(
                id=b.id,
                strategy_version_id=b.strategy_version_id,
                version_no=version.version_no if version else 0,
                risk_policy={
                    "id": rpv.id if rpv else uuid.uuid4(),
                    "name": rp_name,
                    "version_no": rpv.version_no if rpv else 0,
                    "policy_json_summary": rp_policy_json,
                },
                capital_pool={
                    "id": pool.id if pool else uuid.uuid4(),
                    "name": pool.name if pool else "",
                    "pool_type": pool.pool_type if pool else "",
                    "total_budget": float(pool.total_budget) if pool else 0.0,
                    "currency": pool.currency if pool else "",
                    "remaining_budget": float(pool.total_budget) if pool else 0.0,
                },
                mode=b.mode,
                created_at=b.created_at,
            )
        )
    return results


# ═══════════════════════════════════════════════════════════════════════════
# A. GET /{strategy_id}/workspace — BFF aggregation
# ═══════════════════════════════════════════════════════════════════════════


@router.get(
    "/{strategy_id}/workspace",
    response_model=WorkspaceSnapshotResponse,
)
async def get_workspace(
    strategy_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """Return a fully assembled workspace snapshot (11 data sources)."""
    aggregator = StrategyWorkspaceAggregator(db=db)
    try:
        snapshot = await aggregator.get_snapshot(strategy_id)
    except ValueError as e:
        _raise_service_error(e)
        return  # unreachable
    return snapshot


# ═══════════════════════════════════════════════════════════════════════════
# B. POST /{strategy_id}/duplicate
# ═══════════════════════════════════════════════════════════════════════════


@router.post(
    "/{strategy_id}/duplicate",
    response_model=StrategyV2Response,
    status_code=201,
)
def duplicate_strategy(
    strategy_id: uuid.UUID,
    body: DuplicateRequest,
    db: Session = Depends(get_db),
):
    """Clone the latest version as a new draft strategy."""
    activity = StrategyActivityService(db)
    svc = StrategyDuplicateService(db, activity)
    try:
        new = svc.duplicate(strategy_id, name=body.name, actor="api")
    except ValueError as e:
        _raise_service_error(e)
        return  # unreachable
    db.commit()
    db.refresh(new)
    return StrategyV2Response.model_validate(new)


# ═══════════════════════════════════════════════════════════════════════════
# C. GET /{strategy_id}/bindings
# ═══════════════════════════════════════════════════════════════════════════


@router.get(
    "/{strategy_id}/bindings",
    response_model=list[StrategyBindingResponse],
)
def list_bindings(
    strategy_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """List all bindings for a strategy with full risk_policy + capital_pool summaries."""
    svc = StrategyBindingService(db, StrategyActivityService(db))
    raw = svc.list_for_strategy(strategy_id)
    return _build_binding_responses(db, raw)


# ═══════════════════════════════════════════════════════════════════════════
# D. POST /{strategy_id}/bindings
# ═══════════════════════════════════════════════════════════════════════════


@router.post(
    "/{strategy_id}/bindings",
    response_model=StrategyBindingResponse,
    status_code=201,
)
def create_binding(
    strategy_id: uuid.UUID,
    body: CreateBindingRequest,
    db: Session = Depends(get_db),
):
    """Create a new binding for a strategy version."""
    _check_strategy_exists(db, strategy_id)

    activity = StrategyActivityService(db)
    svc = StrategyBindingService(db, activity)
    try:
        b = svc.create(
            strategy_id=strategy_id,
            strategy_version_id=body.strategy_version_id,
            risk_policy_version_id=body.risk_policy_version_id,
            capital_pool_id=body.capital_pool_id,
            mode=body.mode,
            actor="api",
        )
    except (DuplicateBindingError, PoolMismatchError, PolicyArchivedError, ValueError) as e:
        _raise_service_error(e)
        return  # unreachable

    db.commit()
    return _build_binding_responses(db, [b])[0]


# ═══════════════════════════════════════════════════════════════════════════
# E. DELETE /{strategy_id}/bindings/{binding_id}
# ═══════════════════════════════════════════════════════════════════════════


@router.delete(
    "/{strategy_id}/bindings/{binding_id}",
    status_code=204,
)
def delete_binding(
    strategy_id: uuid.UUID,
    binding_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """Delete a binding. Fails with 409 if the binding has active runs."""
    activity = StrategyActivityService(db)
    svc = StrategyBindingService(db, activity)
    try:
        svc.delete(binding_id, actor="api")
    except (BindingInUseError, ValueError) as e:
        _raise_service_error(e)
        return  # unreachable
    db.commit()


# ═══════════════════════════════════════════════════════════════════════════
# F. PATCH /{strategy_id}/archive
# ═══════════════════════════════════════════════════════════════════════════


@router.patch(
    "/{strategy_id}/archive",
    response_model=StrategyV2Response,
)
def archive_strategy(
    strategy_id: uuid.UUID,
    body: ArchiveRequest,
    db: Session = Depends(get_db),
):
    """Archive a strategy and all non-archived versions."""
    activity = StrategyActivityService(db)
    svc = StrategyArchiveService(db, activity)
    try:
        archived = svc.archive(strategy_id, reason=body.reason, actor="api")
    except ValueError as e:
        _raise_service_error(e)
        return  # unreachable
    db.commit()
    db.refresh(archived)
    return StrategyV2Response.model_validate(archived)


# ═══════════════════════════════════════════════════════════════════════════
# G. GET /{strategy_id}/activity
# ═══════════════════════════════════════════════════════════════════════════


@router.get(
    "/{strategy_id}/activity",
    response_model=list[ActivityEntry],
)
def list_activity(
    strategy_id: uuid.UUID,
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    """Return recent activity log entries for a strategy."""
    _check_strategy_exists(db, strategy_id)
    svc = StrategyActivityService(db)
    rows = svc.list_recent(strategy_id, limit=limit)
    return [ActivityEntry.model_validate(r) for r in rows]
