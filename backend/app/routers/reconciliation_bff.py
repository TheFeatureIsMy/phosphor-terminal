"""Reconciliation BFF — Bus view + Runs"""
import logging

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.schemas.execution_bff import (
    ReconciliationBusResponse, ReconciliationRun, CommandBusEvent,
)
from app.schemas.common import AvailableAction
from app.database import get_db

router = APIRouter(prefix="/api/reconciliation", tags=["reconciliation-bff"])
logger = logging.getLogger(__name__)


@router.get("/bus", response_model=ReconciliationBusResponse)
async def get_reconciliation_bus(db: Session = Depends(get_db)):
    try:
        from app.domain.command import CommandBusCommand
        from app.domain.reconciliation import ReconciliationEvent

        # Query recent commands (last 20)
        cmd_stmt = (
            select(CommandBusCommand)
            .order_by(CommandBusCommand.created_at.desc())
            .limit(20)
        )
        commands = list(db.scalars(cmd_stmt).all())

        recent_commands = [
            CommandBusEvent(
                id=str(cmd.id),
                command_type=cmd.command_type,
                status=cmd.status,
                created_at=cmd.created_at,
                completed_at=cmd.completed_at,
            )
            for cmd in commands
        ]

        # Query recent reconciliation runs (last 10)
        recon_stmt = (
            select(ReconciliationEvent)
            .order_by(ReconciliationEvent.started_at.desc())
            .limit(10)
        )
        recon_events = list(db.scalars(recon_stmt).all())

        reconciliation_runs = [
            ReconciliationRun(
                id=str(ev.id),
                status=ev.status,
                started_at=ev.started_at,
                completed_at=ev.completed_at,
                discrepancies=len(ev.drift_summary.get("drifts", [])) if ev.drift_summary else 0,
            )
            for ev in recon_events
        ]

        # Determine overall state
        has_running = any(r.status == "started" for r in recon_events)
        has_failed = any(r.status == "failed" for r in recon_events[:3])
        state = "reconciliating" if has_running else ("degraded" if has_failed else "healthy")

        return ReconciliationBusResponse(
            state=state,
            reason_codes=[],
            available_actions=[
                AvailableAction(type="refresh_exchange_state", enabled=True, label="刷新交易所状态"),
                AvailableAction(type="retry_reconciliation", enabled=True, label="重新对账"),
            ],
            recent_commands=recent_commands,
            reconciliation_runs=reconciliation_runs,
            active_leases=[],
        ).model_dump()
    except Exception as e:
        logger.exception("[reconciliation-bus] DB query failed: %s", e)
        return ReconciliationBusResponse(
            state="data_source_unavailable",
            reason_codes=["data_source_unavailable", type(e).__name__],
            available_actions=[],
            recent_commands=[],
            reconciliation_runs=[],
            active_leases=[],
        ).model_dump()


@router.get("/runs")
async def get_reconciliation_runs(db: Session = Depends(get_db)):
    try:
        from app.domain.reconciliation import ReconciliationEvent

        stmt = (
            select(ReconciliationEvent)
            .order_by(ReconciliationEvent.started_at.desc())
            .limit(50)
        )
        events = list(db.scalars(stmt).all())

        runs = [
            {
                "id": str(ev.id),
                "status": ev.status,
                "strategy_run_id": str(ev.strategy_run_id) if ev.strategy_run_id else None,
                "freqtrade_run_id": str(ev.freqtrade_run_id) if ev.freqtrade_run_id else None,
                "started_at": ev.started_at.isoformat() if ev.started_at else None,
                "completed_at": ev.completed_at.isoformat() if ev.completed_at else None,
                "drift_summary": ev.drift_summary,
                "discrepancies": len(ev.drift_summary.get("drifts", [])) if ev.drift_summary else 0,
            }
            for ev in events
        ]

        return {"runs": runs, "total": len(runs)}
    except Exception:
        return {"runs": [], "total": 0}


@router.post("/runs/{run_id}/retry")
async def retry_reconciliation_run(run_id: str, db: Session = Depends(get_db)):
    try:
        from app.services.reconciliation_service import ReconciliationService

        svc = ReconciliationService(db)
        svc.run_reconciliation(run_id=run_id)
        return {"status": "retrying", "run_id": run_id, "reason_codes": []}
    except Exception as e:
        logger.exception("[recon-retry-single] failed: %s", e)
        return {"status": "failed", "run_id": run_id, "reason_codes": [type(e).__name__]}


@router.post("/retry")
async def retry_reconciliation_batch(db: Session = Depends(get_db)):
    try:
        from app.services.reconciliation_service import ReconciliationService

        svc = ReconciliationService(db)
        svc.run_reconciliation()
        return {"status": "retrying", "affected_count": -1, "reason_codes": []}
    except Exception as e:
        logger.exception("[recon-retry-batch] failed: %s", e)
        return {"status": "failed", "affected_count": 0, "reason_codes": [type(e).__name__]}


@router.post("/refresh-exchange-state")
async def refresh_exchange_state():
    try:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()
        status_data = await ft.get_status()

        if FreqtradeClient.is_success(status_data):
            trades = status_data if isinstance(status_data, list) else status_data.get("trades", [])
            return {
                "status": "refreshed",
                "reason_codes": [],
                "open_trades_count": len(trades),
                "trades_summary": [
                    {
                        "trade_id": t.get("trade_id"),
                        "pair": t.get("pair"),
                        "is_open": t.get("is_open"),
                        "profit_ratio": t.get("profit_ratio"),
                    }
                    for t in trades[:20]
                ],
            }
        else:
            return {
                "status": "refresh_failed",
                "reason_codes": ["freqtrade_error"],
                "error": status_data.get("error", "unknown"),
            }
    except Exception:
        logger.exception("[refresh-exchange-state] FreqtradeClient unavailable")
        return {"status": "refresh_failed", "reason_codes": ["data_source_unavailable"]}
