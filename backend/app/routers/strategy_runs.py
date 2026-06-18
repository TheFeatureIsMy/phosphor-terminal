"""Strategy Runs v2 API — run visibility, orders, and ledger events."""
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.database import get_db
from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.strategy import StrategyVersion
from app.domain.order import ExecutionOrder
from app.domain.ledger import ExecutionLedgerEvent
from app.schemas.strategy_runs import StrategyRunView, StrategyRunDetail, FreqtradeRunView

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
    return run


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
