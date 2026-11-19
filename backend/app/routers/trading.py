"""Trading control router — PRD Live Readiness execution entry points.

Endpoints:
  POST /api/trading/start-paper        paper trading = Freqtrade dry-run via Command Bus
  POST /api/trading/start-live-small   full safety gate chain, gated by LIVE_SMALL_ENABLED
  POST /api/trading/disable-auto       stop active dry-runs + block new entries

All execution goes through the Command Bus (v2.5 ADR-005); this router only
validates, gates, and enqueues — no direct Freqtrade/exchange interaction.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, and_
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.security.deps import get_current_tenant_id
from app.domain.enums import CommandType, StrategyVersionStatus
from app.domain.execution import StrategyRun
from app.domain.order import ExecutionTrade
from app.domain.strategy import StrategyVersion
from app.models.dryrun import DryRunRun
from app.repositories.run_history_repository import RunHistoryStatsRepository
from app.schemas.trading import (
    DisableAutoRequest,
    DisableAutoResponse,
    StartLiveSmallRequest,
    StartLiveSmallResponse,
    DemoProcessResponse,
    StartPaperRequest,
    TradingCommandResponse,
)
from app.services.command_bus import CommandBusService
from app.services.dsl_hasher import compute_dsl_hash
from app.services.live_small import LiveSmallService
from app.services.providers.categories.cex.binance import CONFIRM_PHRASE
from app.services.live_small.circuit_breaker import TradeResult, check_circuit_breaker
from app.services.risk_engine import RiskEngine
from app.services.strategy_transition import validate_transition, InvalidTransitionError

def _tenant_int(raw: str | None) -> int | None:
    try:
        return int(raw) if raw is not None else None
    except (TypeError, ValueError):
        return None




def _tenant_max_open_trades(db, tenant_id: int | None) -> int | None:
    if tenant_id is None:
        return None
    from app.models.tenant import TenantExecutionProfile

    profile = db.query(TenantExecutionProfile).filter(
        TenantExecutionProfile.tenant_id == tenant_id
    ).first()
    if profile is None or not profile.enabled:
        return None
    return profile.max_open_trades


router = APIRouter(prefix="/api/trading", tags=["trading-control"])


@router.get("/demo-process", response_model=DemoProcessResponse)
async def demo_process():
    """Progress of the running simulation process. Empty trades are still a live process."""
    from app.services.demo_process import read_demo_process

    return await read_demo_process()


logger = logging.getLogger(__name__)

_risk_engine = RiskEngine()


def _utcnow_naive() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


@router.post("/start-paper", response_model=TradingCommandResponse, status_code=202)
def start_paper(req: StartPaperRequest, db: Session = Depends(get_db)):
    """Start paper trading — wraps the v2 dry-run command chain.

    Paper mode is a Freqtrade dry-run marked with mode=paper in the command
    payload; no real funds are ever touched.
    """
    version = db.get(StrategyVersion, req.strategy_version_id)
    if version is None:
        raise HTTPException(status_code=404, detail="StrategyVersion not found")

    dsl = version.rule_dsl
    risk_result = _risk_engine.pre_dryrun_check(
        dsl=dsl,
        stake_amount=req.stake_amount,
        initial_wallet=req.initial_wallet,
        max_open_trades=req.max_open_trades,
    )
    if not risk_result.approved:
        raise HTTPException(status_code=422, detail={
            "state": "blocked",
            "reason_codes": ["pre_paper_risk_check_failed"],
            "errors": risk_result.errors,
        })

    dsl_hash = compute_dsl_hash(dsl)
    today = datetime.now(timezone.utc).strftime("%Y%m%d")
    request_token = req.client_request_id or today
    idempotency_key = f"start_paper:{req.strategy_version_id}:{dsl_hash}:paper:{request_token}"

    svc = CommandBusService(db)
    cmd, created = svc.enqueue(
        command_type=CommandType.START_DRYRUN.value,
        aggregate_type="strategy_version",
        aggregate_id=req.strategy_version_id,
        payload={
            "dsl": dsl,
            "dsl_hash": dsl_hash,
            "symbols": req.symbols,
            "stake_amount": req.stake_amount,
            "max_open_trades": req.max_open_trades,
            "initial_wallet": req.initial_wallet,
            "exchange": req.exchange,
            "api_port": req.api_port,
            "strategy_id": None,
            "strategy_version_id": str(req.strategy_version_id),
            "mode": "paper",
        },
        idempotency_key=idempotency_key,
        requested_by="api:trading/start-paper",
        timeout_sec=120,
    )
    db.commit()
    db.refresh(cmd)

    return TradingCommandResponse(
        state="running",
        reason_codes=[],
        available_actions=[],
        command_id=cmd.id,
        command_status=cmd.status,
        idempotency_key=idempotency_key,
        message="paper trading command enqueued" if created else "command already exists",
    )


@router.post("/start-live-small", response_model=StartLiveSmallResponse)
def start_live_small(
    req: StartLiveSmallRequest,
    db: Session = Depends(get_db),
    tenant_raw: str | None = Depends(get_current_tenant_id),
):
    """Start live_small trading — only after the full safety gate chain passes.

    Gate chain: human confirmation → preconditions → risk approval →
    circuit breaker → version live_pending → LIVE_SMALL_ENABLED switch.
    The actual run creation happens asynchronously via REQUEST_LIVE_SMALL
    command (Command Bus); this endpoint never touches Freqtrade directly.
    """
    repo = RunHistoryStatsRepository(db)
    stats = repo.build_stats(req.strategy_version_id)
    svc = LiveSmallService(db)
    approval = svc.evaluate_approval(
        strategy_version_id=req.strategy_version_id,
        capital_pool_id=req.capital_pool_id,
        run_history=stats,
        exchange_name=req.exchange_name,
        tenant_id=_tenant_int(tenant_raw),
    )

    blocked_reasons = [
        item.name for item in approval.preconditions.items if not item.passed
    ] + [e.get("code", "risk_error") for e in approval.risk_errors]

    if not approval.can_proceed:
        return StartLiveSmallResponse(
            state="blocked",
            reason_codes=blocked_reasons or ["approval_failed"],
            available_actions=[{"type": "view_readiness", "enabled": True, "label": "查看实盘准入"}],
            can_proceed=False,
            live_small_enabled=settings.live_small_enabled,
            preconditions=approval.preconditions,
            risk_errors=approval.risk_errors,
            config_preview=approval.config_preview,
        )

    # Human confirmation is mandatory (capital pool requires_human_confirm).
    if not req.human_confirmed or not req.confirmed_by:
        return StartLiveSmallResponse(
            state="waiting_confirmation",
            reason_codes=["human_confirmation_required"],
            available_actions=[{"type": "confirm_live_small", "enabled": True,
                                "label": "人工确认启动小仓实盘", "confirm_required": True}],
            can_proceed=True,
            live_small_enabled=settings.live_small_enabled,
            preconditions=approval.preconditions,
            config_preview=approval.config_preview,
        )

    # Circuit breaker gate: today's losses on the latest run of this version.
    cb = _check_circuit_breaker_for_version(db, req.strategy_version_id)
    if cb is not None and cb["should_stop"]:
        return StartLiveSmallResponse(
            state="blocked",
            reason_codes=["circuit_breaker_tripped"] + list(cb["reasons"]),
            available_actions=[],
            can_proceed=True,
            live_small_enabled=settings.live_small_enabled,
            preconditions=approval.preconditions,
            config_preview=approval.config_preview,
        )

    # Deployment switch: live_small execution is off by default (v2.5 rollout).
    if not settings.live_small_enabled:
        return StartLiveSmallResponse(
            state="not_enabled",
            reason_codes=["live_small_execution_not_enabled"],
            available_actions=[],
            can_proceed=True,
            live_small_enabled=False,
            preconditions=approval.preconditions,
            config_preview=approval.config_preview,
        )

    if req.confirmed_by != CONFIRM_PHRASE:
        return StartLiveSmallResponse(
            state="waiting_confirmation",
            reason_codes=["confirm_phrase_required"],
            available_actions=[{"type": "confirm_live_small", "enabled": True,
                                "label": "人工确认启动小仓实盘", "confirm_required": True}],
            can_proceed=True,
            live_small_enabled=True,
            preconditions=approval.preconditions,
            config_preview=approval.config_preview,
        )

    # Final state gate: promote paper_passed → live_pending (the
    # RequestLiveSmallHandler requires live_pending); anything else is blocked.
    version = db.get(StrategyVersion, req.strategy_version_id)
    if version.status == StrategyVersionStatus.PAPER_PASSED.value:
        try:
            validate_transition(
                StrategyVersionStatus.PAPER_PASSED, StrategyVersionStatus.LIVE_PENDING,
            )
        except InvalidTransitionError:  # pragma: no cover — static table allows it
            return StartLiveSmallResponse(
                state="blocked", reason_codes=["invalid_version_transition"],
                can_proceed=True, live_small_enabled=True,
                preconditions=approval.preconditions,
            )
        version.status = StrategyVersionStatus.LIVE_PENDING.value
        db.flush()
    elif version.status != StrategyVersionStatus.LIVE_PENDING.value:
        return StartLiveSmallResponse(
            state="blocked",
            reason_codes=["version_not_live_pending"],
            available_actions=[],
            can_proceed=True,
            live_small_enabled=True,
            preconditions=approval.preconditions,
            config_preview=approval.config_preview,
        )

    idempotency_key = (
        f"start_live_small:{req.strategy_version_id}:{req.capital_pool_id}:"
        f"{datetime.now(timezone.utc).strftime('%Y%m%d')}"
    )
    bus = CommandBusService(db)
    cmd, created = bus.enqueue(
        command_type=CommandType.REQUEST_LIVE_SMALL.value,
        aggregate_type="strategy_version",
        aggregate_id=req.strategy_version_id,
        payload={
            "strategy_version_id": str(req.strategy_version_id),
            "capital_pool_id": str(req.capital_pool_id),
            "exchange_name": req.exchange_name,
            "confirmed_by": req.confirmed_by,
            "tenant_id": _tenant_int(tenant_raw),
            "max_open_trades_cap": _tenant_max_open_trades(
                db, _tenant_int(tenant_raw)
            ),
        },
        idempotency_key=idempotency_key,
        requested_by=f"api:trading/start-live-small:{req.confirmed_by}",
        timeout_sec=60,
    )
    db.commit()
    db.refresh(cmd)

    return StartLiveSmallResponse(
        state="approved_enqueued",
        reason_codes=[],
        available_actions=[],
        command_id=cmd.id,
        command_status=cmd.status,
        can_proceed=True,
        live_small_enabled=True,
        preconditions=approval.preconditions,
        config_preview=approval.config_preview,
    )


def _check_circuit_breaker_for_version(db: Session, strategy_version_id: uuid.UUID) -> dict | None:
    """Run the daily circuit breaker against the latest run of the version.

    Returns None when there is no prior run to evaluate.
    """
    from app.domain.risk import CapitalPool, StrategyRiskPolicyBinding

    run = db.scalar(
        select(StrategyRun)
        .where(StrategyRun.strategy_version_id == strategy_version_id)
        .order_by(StrategyRun.created_at.desc())
        .limit(1)
    )
    if run is None:
        return None

    today_start = _utcnow_naive().replace(hour=0, minute=0, second=0, microsecond=0)
    trades = list(db.scalars(
        select(ExecutionTrade)
        .where(and_(
            ExecutionTrade.strategy_run_id == run.id,
            ExecutionTrade.status == "closed",
            ExecutionTrade.closed_at >= today_start,
        ))
        .order_by(ExecutionTrade.closed_at)
    ).all())

    trade_results = [
        TradeResult(
            profit_abs=float(t.profit_abs or 0),
            profit_pct=float(t.profit_pct or 0),
            is_win=float(t.profit_abs or 0) >= 0,
        )
        for t in trades
    ]

    total_budget = 10000.0
    max_daily_loss_pct = 0.03
    binding = db.scalar(
        select(StrategyRiskPolicyBinding)
        .where(and_(
            StrategyRiskPolicyBinding.strategy_version_id == strategy_version_id,
            StrategyRiskPolicyBinding.mode == "live_small",
        ))
        .limit(1)
    )
    if binding:
        pool = db.get(CapitalPool, binding.capital_pool_id)
        if pool:
            total_budget = float(pool.total_budget)
            max_daily_loss_pct = float(pool.max_daily_loss_pct)

    return check_circuit_breaker(
        trades_today=trade_results,
        total_budget=total_budget,
        max_daily_loss_pct=max_daily_loss_pct,
    )


@router.post("/disable-auto", response_model=DisableAutoResponse)
def disable_auto(req: DisableAutoRequest, db: Session = Depends(get_db)):
    """Disable automated trading: stop all active dry-runs and block new entries."""
    from app.services.account_risk_firewall import AccountRiskFirewall

    active_runs = list(db.scalars(
        select(DryRunRun).where(DryRunRun.status.in_(["starting", "running"]))
    ).all())

    bus = CommandBusService(db)
    command_ids: list[uuid.UUID] = []
    hour_bucket = datetime.now(timezone.utc).strftime("%Y%m%d%H")
    for run in active_runs:
        cmd, _created = bus.enqueue(
            command_type=CommandType.STOP_DRYRUN.value,
            aggregate_type="dryrun_run",
            payload={"dryrun_run_id": run.id, "reason": req.reason},
            idempotency_key=f"disable_auto:{run.id}:{hour_bucket}",
            requested_by=f"api:trading/disable-auto:{req.reason}",
            timeout_sec=60,
        )
        command_ids.append(cmd.id)

    try:
        AccountRiskFirewall.activate_manual_block(
            reason=req.reason, db=db, updated_by="api:trading/disable-auto",
        )
        firewall_active = True
    except Exception as e:  # pragma: no cover — firewall is in-memory
        logger.exception("[disable-auto] firewall activation failed: %s", e)
        firewall_active = False

    db.commit()

    return DisableAutoResponse(
        state="blocked",
        reason_codes=["auto_trading_disabled"],
        available_actions=[{"type": "unblock", "enabled": True, "label": "解除新入场封锁"}],
        stopped_dryruns=len(active_runs),
        command_ids=command_ids,
        firewall_active=firewall_active,
    )
