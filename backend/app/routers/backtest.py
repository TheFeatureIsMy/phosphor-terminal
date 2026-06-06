"""Backtest API — v2.5: all backtests go through Command Bus (ADR-005)."""
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.domain.enums import CommandType
from app.models.strategy import BacktestRun
from app.schemas.backtest_v2 import (
    StartBacktestRequest,
    StartBacktestResponse,
    BacktestRunResponse,
    BacktestStatusResponse,
)
from app.services.command_bus import CommandBusService
from app.services.dsl_hasher import compute_dsl_hash
from app.services.risk_engine import RiskEngine

router = APIRouter(prefix="/api/v2/backtest", tags=["backtest"])

_risk_engine = RiskEngine()


@router.post("", response_model=StartBacktestResponse, status_code=202)
def start_backtest(req: StartBacktestRequest, db: Session = Depends(get_db)):
    risk_result = _risk_engine.pre_backtest_check(
        dsl=req.dsl,
        timerange=req.timerange,
        initial_capital=req.initial_capital,
    )
    if not risk_result.approved:
        raise HTTPException(status_code=422, detail={
            "message": "pre-backtest risk check failed",
            "errors": risk_result.errors,
        })

    dsl_hash = compute_dsl_hash(req.dsl)
    today = datetime.now(timezone.utc).strftime("%Y%m%d")
    idempotency_key = (
        f"start_backtest:{req.strategy_version_id or req.strategy_id}"
        f":{dsl_hash}:backtest:{today}"
    )

    svc = CommandBusService(db)
    cmd, created = svc.enqueue(
        command_type=CommandType.START_BACKTEST.value,
        aggregate_type="strategy_version",
        aggregate_id=uuid.UUID(req.strategy_version_id) if req.strategy_version_id else None,
        payload={
            "dsl": req.dsl,
            "dsl_hash": dsl_hash,
            "timerange": req.timerange,
            "symbols": req.symbols,
            "initial_capital": req.initial_capital,
            "stake_amount": req.stake_amount,
            "max_open_trades": req.max_open_trades,
            "exchange": req.exchange,
            "fee": req.fee,
            "strategy_id": req.strategy_id,
            "strategy_version_id": req.strategy_version_id,
        },
        idempotency_key=idempotency_key,
        requested_by="api",
        timeout_sec=600,
    )
    db.commit()
    db.refresh(cmd)

    return StartBacktestResponse(
        command_id=cmd.id,
        status=cmd.status,
        message="backtest command enqueued" if created else "command already exists",
        idempotency_key=idempotency_key,
    )


@router.get("/status/{command_id}", response_model=BacktestStatusResponse)
def get_backtest_status(command_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = CommandBusService(db)
    cmd = svc.get_by_id(command_id)
    if cmd is None:
        raise HTTPException(status_code=404, detail="Command not found")

    run = (
        db.query(BacktestRun)
        .filter(BacktestRun.command_id == str(command_id))
        .first()
    )

    return BacktestStatusResponse(
        command_id=cmd.id,
        command_status=cmd.status,
        backtest_run=BacktestRunResponse.model_validate(run) if run else None,
        error_code=cmd.error_code,
        error_message=cmd.error_message,
    )


@router.get("", response_model=list[BacktestRunResponse])
def list_backtests(
    limit: int = 50,
    offset: int = 0,
    strategy_id: int | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(BacktestRun)
    if strategy_id is not None:
        query = query.filter(BacktestRun.strategy_id == strategy_id)
    runs = (
        query
        .order_by(BacktestRun.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return [BacktestRunResponse.model_validate(r) for r in runs]


@router.get("/{backtest_id}", response_model=BacktestRunResponse)
def get_backtest(backtest_id: int, db: Session = Depends(get_db)):
    run = db.query(BacktestRun).filter(BacktestRun.id == backtest_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="Backtest not found")
    return BacktestRunResponse.model_validate(run)
