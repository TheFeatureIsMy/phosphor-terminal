"""Dry-run API — v2.5: all dry-runs go through Command Bus (ADR-005)."""
import asyncio
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.domain.enums import CommandType
from app.models.dryrun import DryRunRun
from app.schemas.dryrun_v2 import (
    StartDryRunRequest,
    StartDryRunResponse,
    StopDryRunRequest,
    StopDryRunResponse,
    DryRunRunResponse,
    DryRunStatusResponse,
    DryRunSyncResponse,
)
from app.services.command_bus import CommandBusService
from app.services.dsl_hasher import compute_dsl_hash
from app.services.dryrun_sync import DryRunSyncService
from app.services.risk_engine import RiskEngine

router = APIRouter(prefix="/api/v2/dryrun", tags=["dryrun"])

_risk_engine = RiskEngine()


@router.post("", response_model=StartDryRunResponse, status_code=202)
def start_dryrun(req: StartDryRunRequest, db: Session = Depends(get_db)):
    risk_result = _risk_engine.pre_dryrun_check(
        dsl=req.dsl,
        stake_amount=req.stake_amount,
        initial_wallet=req.initial_wallet,
        max_open_trades=req.max_open_trades,
    )
    if not risk_result.approved:
        raise HTTPException(status_code=422, detail={
            "message": "pre-dryrun risk check failed",
            "errors": risk_result.errors,
        })

    dsl_hash = compute_dsl_hash(req.dsl)
    today = datetime.now(timezone.utc).strftime("%Y%m%d")
    idempotency_key = (
        f"start_dryrun:{req.strategy_version_id or req.strategy_id}"
        f":{dsl_hash}:dryrun:{today}"
    )

    svc = CommandBusService(db)
    cmd, created = svc.enqueue(
        command_type=CommandType.START_DRYRUN.value,
        aggregate_type="strategy_version",
        aggregate_id=uuid.UUID(req.strategy_version_id) if req.strategy_version_id else None,
        payload={
            "dsl": req.dsl,
            "dsl_hash": dsl_hash,
            "symbols": req.symbols,
            "stake_amount": req.stake_amount,
            "max_open_trades": req.max_open_trades,
            "initial_wallet": req.initial_wallet,
            "exchange": req.exchange,
            "api_port": req.api_port,
            "strategy_id": req.strategy_id,
            "strategy_version_id": req.strategy_version_id,
        },
        idempotency_key=idempotency_key,
        requested_by="api",
        timeout_sec=120,
    )
    db.commit()
    db.refresh(cmd)

    return StartDryRunResponse(
        command_id=cmd.id,
        status=cmd.status,
        message="dry-run command enqueued" if created else "command already exists",
        idempotency_key=idempotency_key,
    )


@router.post("/{dryrun_id}/stop", response_model=StopDryRunResponse, status_code=202)
def stop_dryrun(
    dryrun_id: int,
    req: StopDryRunRequest = StopDryRunRequest(),
    db: Session = Depends(get_db),
):
    run = db.query(DryRunRun).filter(DryRunRun.id == dryrun_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="DryRunRun not found")

    if run.status in ("stopped", "failed"):
        raise HTTPException(status_code=409, detail=f"dry-run already {run.status}")

    idempotency_key = f"stop_dryrun:{dryrun_id}:{datetime.now(timezone.utc).strftime('%Y%m%d%H')}"

    svc = CommandBusService(db)
    cmd, created = svc.enqueue(
        command_type=CommandType.STOP_DRYRUN.value,
        aggregate_type="dryrun_run",
        payload={
            "dryrun_run_id": dryrun_id,
            "reason": req.reason,
        },
        idempotency_key=idempotency_key,
        requested_by="api",
        timeout_sec=60,
    )
    db.commit()
    db.refresh(cmd)

    return StopDryRunResponse(
        command_id=cmd.id,
        status=cmd.status,
        message="stop command enqueued" if created else "stop command already exists",
    )


@router.get("/status/{command_id}", response_model=DryRunStatusResponse)
def get_dryrun_status(command_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = CommandBusService(db)
    cmd = svc.get_by_id(command_id)
    if cmd is None:
        raise HTTPException(status_code=404, detail="Command not found")

    run = db.query(DryRunRun).filter(DryRunRun.command_id == str(command_id)).first()

    return DryRunStatusResponse(
        command_id=cmd.id,
        command_status=cmd.status,
        dryrun_run=DryRunRunResponse.model_validate(run) if run else None,
        error_code=cmd.error_code,
        error_message=cmd.error_message,
    )


@router.get("", response_model=list[DryRunRunResponse])
def list_dryruns(
    limit: int = 50,
    offset: int = 0,
    strategy_version_id: uuid.UUID | None = Query(
        None, description="Filter by strategy version UUID (DryRunRun.strategy_version_id as text)",
    ),
    db: Session = Depends(get_db),
):
    query = db.query(DryRunRun)
    if strategy_version_id is not None:
        query = query.filter(DryRunRun.strategy_version_id == str(strategy_version_id))
    runs = (
        query
        .order_by(DryRunRun.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return [DryRunRunResponse.model_validate(r) for r in runs]


@router.get("/{dryrun_id}", response_model=DryRunRunResponse)
def get_dryrun(dryrun_id: int, db: Session = Depends(get_db)):
    run = db.query(DryRunRun).filter(DryRunRun.id == dryrun_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="DryRunRun not found")
    return DryRunRunResponse.model_validate(run)


@router.post("/{dryrun_id}/sync", response_model=DryRunSyncResponse)
async def sync_dryrun(dryrun_id: int, db: Session = Depends(get_db)):
    run = db.query(DryRunRun).filter(DryRunRun.id == dryrun_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="DryRunRun not found")

    if run.status != "running":
        raise HTTPException(status_code=409, detail=f"dry-run is {run.status}, not running")

    sync_svc = DryRunSyncService(session=db, api_url=run.api_url)
    result = await sync_svc.sync_trades(dryrun_run_id=run.id)

    run.total_trades = (run.total_trades or 0) + result.closed_trades
    run.open_trades = result.open_trades
    run.last_synced_at = datetime.now(timezone.utc)
    db.commit()

    return DryRunSyncResponse(
        dryrun_run_id=run.id,
        new_events=result.new_events,
        open_trades=result.open_trades,
        closed_trades=result.closed_trades,
        success=result.success,
        errors=result.errors,
    )
