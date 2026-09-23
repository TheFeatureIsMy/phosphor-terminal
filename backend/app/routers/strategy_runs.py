"""Strategy Runs v2 API — run visibility, orders, ledger events, lifecycle control."""
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Body, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.database import get_db
from app.domain.enums import CommandType
from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.strategy import StrategyVersion
from app.domain.order import ExecutionOrder
from app.domain.ledger import ExecutionLedgerEvent
from app.models.dryrun import DryRunRun
from app.schemas.strategy_runs import (
    RunExecutionSummary,
    StrategyRunDetail,
    StrategyRunView,
    FreqtradeRunView,
)
from app.services.command_bus import CommandBusService

router = APIRouter(prefix="/api/v2/strategy-runs", tags=["strategy-runs"])


@router.get("", response_model=list[StrategyRunView])
def list_strategy_runs(
    mode: str | None = None,
    status: str | None = None,
    strategy_version_id: uuid.UUID | None = Query(None, description="Filter by strategy version UUID"),
    strategy_id: uuid.UUID | None = Query(None, description="Filter by strategy UUID (joins through StrategyVersion)"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    q = db.query(StrategyRun)
    if mode:
        q = q.filter(StrategyRun.mode == mode)
    if status:
        q = q.filter(StrategyRun.status == status)
    if strategy_version_id:
        q = q.filter(StrategyRun.strategy_version_id == strategy_version_id)
    if strategy_id:
        q = q.join(StrategyVersion, StrategyVersion.id == StrategyRun.strategy_version_id).filter(
            StrategyVersion.strategy_id == strategy_id,
        )
    runs = q.order_by(desc(StrategyRun.created_at)).offset(offset).limit(limit).all()
    return runs


@router.get("/{run_id}", response_model=StrategyRunDetail)
def get_strategy_run(run_id: uuid.UUID, db: Session = Depends(get_db)):
    run = db.get(StrategyRun, run_id)
    if not run:
        raise HTTPException(status_code=404, detail="StrategyRun not found")
    detail = StrategyRunDetail.model_validate(run)
    detail.execution = _execution_summary(db, run_id)
    return detail


def _execution_summary(db: Session, run_id: uuid.UUID) -> RunExecutionSummary:
    """Aggregate real execution facts (orders / positions / ledger activity)."""
    from sqlalchemy import func, select

    from app.domain.order import ExecutionOrder, ExecutionPosition

    def count(model, *filters) -> int:
        stmt = select(func.count()).select_from(model).where(
            model.strategy_run_id == run_id, *filters,
        )
        return db.scalar(stmt) or 0

    orders_total = count(ExecutionOrder)
    orders_open = count(ExecutionOrder, ExecutionOrder.status.in_(["open", "partially_filled"]))
    orders_pending = count(ExecutionOrder, ExecutionOrder.status == "pending")
    positions_open = count(ExecutionPosition, ExecutionPosition.status == "open")

    last_event_at = db.scalar(
        select(ExecutionLedgerEvent.event_time)
        .where(ExecutionLedgerEvent.strategy_run_id == run_id)
        .order_by(desc(ExecutionLedgerEvent.event_time))
        .limit(1)
    )

    return RunExecutionSummary(
        orders_total=orders_total,
        orders_open=orders_open,
        orders_pending=orders_pending,
        positions_open=positions_open,
        last_ledger_event_at=last_event_at,
    )


@router.get("/{run_id}/orders")
def get_run_orders(
    run_id: uuid.UUID,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    run = db.get(StrategyRun, run_id)
    if not run:
        raise HTTPException(status_code=404, detail="StrategyRun not found")
    orders = db.query(ExecutionOrder).filter(
        ExecutionOrder.strategy_run_id == run_id,
    ).order_by(desc(ExecutionOrder.opened_at)).offset(offset).limit(limit).all()
    return [{"id": str(o.id), "symbol": o.symbol, "side": o.side, "status": o.status,
             "amount": float(o.amount) if o.amount else None,
             "price": float(o.price) if o.price else None,
             "opened_at": str(o.opened_at) if o.opened_at else None} for o in orders]


@router.get("/{run_id}/ledger")
def get_run_ledger(
    run_id: uuid.UUID,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    run = db.get(StrategyRun, run_id)
    if not run:
        raise HTTPException(status_code=404, detail="StrategyRun not found")
    events = db.query(ExecutionLedgerEvent).filter(
        ExecutionLedgerEvent.strategy_run_id == run_id,
    ).order_by(desc(ExecutionLedgerEvent.event_time)).offset(offset).limit(limit).all()
    return [{"id": str(e.id), "event_type": e.event_type, "source_system": e.source_system,
             "event_time": str(e.event_time), "normalized_payload": e.normalized_payload} for e in events]


def _enqueue_run_command(
    db: Session, run: StrategyRun, command_type: str, action: str, reason: str,
) -> dict:
    """Enqueue a lifecycle command for a run via the Command Bus (ADR-005)."""
    bucket = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    bus = CommandBusService(db)
    cmd, created = bus.enqueue(
        command_type=command_type,
        aggregate_type="strategy_run",
        aggregate_id=run.id,
        payload={"reason": reason},
        idempotency_key=f"{action}:{run.id}:{bucket}",
        requested_by=f"api:strategy-runs/{action}",
        timeout_sec=60,
    )
    db.commit()
    db.refresh(cmd)
    return {
        "state": "running",
        "reason_codes": [],
        "command_id": str(cmd.id),
        "command_status": cmd.status,
        "strategy_run_id": str(run.id),
        "message": f"{action} command enqueued" if created else "command already exists",
    }


@router.post("/{run_id}/pause")
def pause_strategy_run(
    run_id: uuid.UUID,
    payload: dict | None = Body(default=None),
    db: Session = Depends(get_db),
):
    """Pause a running strategy run (marks run stopped, version paused)."""
    run = db.get(StrategyRun, run_id)
    if not run:
        raise HTTPException(status_code=404, detail="StrategyRun not found")
    reason = (payload or {}).get("reason", "user_requested")
    return _enqueue_run_command(db, run, CommandType.PAUSE_STRATEGY.value, "pause_run", reason)


@router.post("/{run_id}/resume")
def resume_strategy_run(
    run_id: uuid.UUID,
    payload: dict | None = Body(default=None),
    db: Session = Depends(get_db),
):
    """Resume a paused/stopped strategy run."""
    run = db.get(StrategyRun, run_id)
    if not run:
        raise HTTPException(status_code=404, detail="StrategyRun not found")
    reason = (payload or {}).get("reason", "user_requested")
    return _enqueue_run_command(db, run, CommandType.RESUME_STRATEGY.value, "resume_run", reason)


@router.post("/{run_id}/stop")
def stop_strategy_run(
    run_id: uuid.UUID,
    payload: dict | None = Body(default=None),
    db: Session = Depends(get_db),
):
    """Stop a strategy run and any active dry-run processes bound to its version."""
    run = db.get(StrategyRun, run_id)
    if not run:
        raise HTTPException(status_code=404, detail="StrategyRun not found")
    reason = (payload or {}).get("reason", "user_requested")
    result = _enqueue_run_command(db, run, CommandType.PAUSE_STRATEGY.value, "stop_run", reason)

    # Also stop active dry-run processes for the same strategy version.
    bus = CommandBusService(db)
    hour_bucket = datetime.now(timezone.utc).strftime("%Y%m%d%H")
    stopped_dryruns = 0
    active_dryruns = db.query(DryRunRun).filter(
        DryRunRun.strategy_version_id == str(run.strategy_version_id),
        DryRunRun.status.in_(["starting", "running"]),
    ).all()
    for dr in active_dryruns:
        bus.enqueue(
            command_type=CommandType.STOP_DRYRUN.value,
            aggregate_type="dryrun_run",
            payload={"dryrun_run_id": dr.id, "reason": reason},
            idempotency_key=f"stop_run_dryrun:{dr.id}:{hour_bucket}",
            requested_by="api:strategy-runs/stop",
            timeout_sec=60,
        )
        stopped_dryruns += 1
    if stopped_dryruns:
        db.commit()
    result["stopped_dryruns"] = stopped_dryruns
    return result
