"""live_small router — safety check endpoints only, no execution.

All endpoints return approval status and config previews.
No endpoint triggers actual Freqtrade start or exchange interaction.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, and_
from sqlalchemy.orm import Session

from app.database import get_db
from app.domain.order import ExecutionTrade
from app.repositories.run_history_repository import RunHistoryStatsRepository
from app.schemas.live_small import (
    CircuitBreakerCheckRequest,
    CircuitBreakerResult,
    ConfigPreviewRequest,
    FreqtradeConfigPreview,
    LiveSmallApprovalResponse,
    PreconditionCheckRequest,
    PreconditionReport,
)
from app.services.live_small import LiveSmallService
from app.services.live_small.circuit_breaker import TradeResult, check_circuit_breaker

router = APIRouter(prefix="/api/live-small", tags=["live-small-safety"])


def _svc(db: Session = Depends(get_db)) -> LiveSmallService:
    return LiveSmallService(db)


@router.post("/precondition-check", response_model=PreconditionReport)
def precondition_check(body: PreconditionCheckRequest, db: Session = Depends(get_db)):
    from app.services.live_small.precondition_checker import check_preconditions
    repo = RunHistoryStatsRepository(db)
    stats = repo.build_stats(body.strategy_version_id)
    report = check_preconditions(stats)
    report.strategy_version_id = body.strategy_version_id
    report.capital_pool_id = body.capital_pool_id
    return report


@router.post("/evaluate", response_model=LiveSmallApprovalResponse)
def evaluate_approval(
    body: PreconditionCheckRequest,
    exchange_name: str = "binance",
    svc: LiveSmallService = Depends(_svc),
):
    repo = RunHistoryStatsRepository(svc._db)
    stats = repo.build_stats(body.strategy_version_id)
    return svc.evaluate_approval(
        strategy_version_id=body.strategy_version_id,
        capital_pool_id=body.capital_pool_id,
        run_history=stats,
        exchange_name=exchange_name,
    )


@router.post("/config-preview", response_model=FreqtradeConfigPreview)
def config_preview(
    body: ConfigPreviewRequest,
    svc: LiveSmallService = Depends(_svc),
):
    from app.domain.risk import CapitalPool
    from app.domain.strategy import StrategyVersion
    from app.schemas.live_small import CapitalPoolParams
    from app.services.live_small.config_generator import generate_config_preview

    db = svc._db
    version = db.get(StrategyVersion, body.strategy_version_id)
    if not version:
        raise HTTPException(status_code=404, detail="StrategyVersion not found")

    pool = db.get(CapitalPool, body.capital_pool_id)
    if not pool:
        raise HTTPException(status_code=404, detail="CapitalPool not found")

    pool_params = CapitalPoolParams(
        total_budget=float(pool.total_budget),
        max_position_pct_per_trade=float(pool.max_position_pct_per_trade),
        max_total_exposure_pct=float(pool.max_total_exposure_pct),
        max_daily_loss_pct=float(pool.max_daily_loss_pct),
        max_drawdown_pct=float(pool.max_drawdown_pct),
    )

    return generate_config_preview(
        dsl=version.rule_dsl,
        pool=pool_params,
        exchange_name=body.exchange_name,
    )


@router.post("/circuit-breaker-check", response_model=CircuitBreakerResult)
def circuit_breaker_check(body: CircuitBreakerCheckRequest, db: Session = Depends(get_db)):
    from app.domain.execution import StrategyRun
    from app.domain.risk import CapitalPool, StrategyRiskPolicyBinding

    run = db.get(StrategyRun, body.strategy_run_id)
    if not run:
        raise HTTPException(status_code=404, detail="StrategyRun not found")

    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0,
    ).replace(tzinfo=None)

    stmt = (
        select(ExecutionTrade)
        .where(and_(
            ExecutionTrade.strategy_run_id == run.id,
            ExecutionTrade.status == "closed",
            ExecutionTrade.closed_at >= today_start,
        ))
        .order_by(ExecutionTrade.closed_at)
    )
    trades = list(db.scalars(stmt).all())

    trade_results = []
    for t in trades:
        profit = float(t.profit_abs or 0)
        pct = float(t.profit_pct or 0)
        trade_results.append(TradeResult(
            profit_abs=profit,
            profit_pct=pct,
            is_win=profit >= 0,
        ))

    binding_stmt = (
        select(StrategyRiskPolicyBinding)
        .where(and_(
            StrategyRiskPolicyBinding.strategy_version_id == run.strategy_version_id,
            StrategyRiskPolicyBinding.mode == "live_small",
        ))
        .limit(1)
    )
    binding = db.scalar(binding_stmt)

    total_budget = 10000.0
    max_daily_loss_pct = 0.03
    max_consecutive_losses = 3

    if binding:
        pool = db.get(CapitalPool, binding.capital_pool_id)
        if pool:
            total_budget = float(pool.total_budget)
            max_daily_loss_pct = float(pool.max_daily_loss_pct)

    result = check_circuit_breaker(
        trades_today=trade_results,
        total_budget=total_budget,
        max_daily_loss_pct=max_daily_loss_pct,
        max_consecutive_losses=max_consecutive_losses,
    )

    return CircuitBreakerResult(
        should_stop=result["should_stop"],
        reasons=result["reasons"],
        daily_loss_pct=result["daily_loss_pct"],
        consecutive_losses=result["consecutive_losses"],
        total_trades_today=result["total_trades_today"],
    )
