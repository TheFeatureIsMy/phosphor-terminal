"""Risk BFF — Overview + Stop Protection + Circuit Breakers"""
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import JSONResponse

from app.schemas.risk_bff import (
    RiskOverviewResponse, RiskGuard,
    StopProtectionResponse, PositionStop, StopLevel,
    CircuitBreakersResponse, CircuitBreakerRecord,
    RiskRulesResponse, ResolveResponse,
)
from app.schemas.common import AvailableAction
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.database import get_db

from app.services.account_risk_firewall import AccountRiskFirewall
from app.services.risk_rules_service import RiskRulesService

router = APIRouter(prefix="/api/risk", tags=["risk-bff"])
logger = logging.getLogger(__name__)


@router.get("/overview", response_model=RiskOverviewResponse)
async def get_risk_overview(
    strategy_id: uuid.UUID | None = Query(
        None, description="Strategy UUID — when provided, returns per-strategy risk state",
    ),
    db: Session = Depends(get_db),
):
    if strategy_id is not None:
        try:
            from app.services.live_readiness_service import LiveReadinessService

            svc = LiveReadinessService()
            readiness = svc.compute_for_strategy(strategy_id, db)

            # Extract risk_config and capital gates as risk guards
            guards: list[RiskGuard] = []
            key_label_map = {
                "risk_config": "风控配置",
                "capital": "资金配置",
            }
            for gate in readiness.strategy_gates:
                if gate.key in key_label_map:
                    guards.append(RiskGuard(
                        key=gate.key,
                        label=key_label_map[gate.key],
                        current_value=1.0 if gate.status == "healthy" else 0.0,
                        limit_value=1.0,
                        remaining_pct=1.0 if gate.status == "healthy" else 0.0,
                        status=gate.status,
                        reason_codes=gate.reason_codes,
                    ))

            failed = [g for g in guards if g.status != "healthy"]
            state = "healthy" if not failed else "warning"
            account_state = readiness.grand_status

            return RiskOverviewResponse(
                state=state,
                reason_codes=[r for g in failed for r in g.reason_codes],
                available_actions=[],
                account_state=account_state,
                emergency_locked=readiness.grand_status == "not_live",
                guards=guards,
                active_locks=[],
            ).model_dump()
        except Exception as e:
            logger.exception("[risk-overview] per-strategy path failed: %s", e)
            return RiskOverviewResponse(
                state="data_source_unavailable",
                reason_codes=["data_source_unavailable", type(e).__name__],
                available_actions=[],
                account_state="unknown",
                emergency_locked=False,
                guards=[],
                active_locks=[],
            ).model_dump()

    try:
        from app.services.bff.risk_aggregator import RiskAggregator
        agg = RiskAggregator()
        return await agg.overview()
    except Exception as e:
        logger.exception("[risk-overview] RiskAggregator unavailable: %s", e)
        return RiskOverviewResponse(
            state="data_source_unavailable",
            reason_codes=["data_source_unavailable", type(e).__name__],
            available_actions=[],
            account_state="unknown",
            emergency_locked=False,
            guards=[],
            active_locks=[],
        ).model_dump()


@router.get("/stop-protection", response_model=StopProtectionResponse)
async def get_stop_protection():
    try:
        from app.services.stop_protection_service import StopProtectionService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.services.freqtrade_client import FreqtradeClient
        from app.config import settings

        store = RuntimeRedisStore(redis_url=settings.redis_url)
        svc = StopProtectionService(redis_store=store)
        result = await svc.get_all()

        # Enhance with real exchange stop data from Freqtrade
        exchange_stops: dict[str, float | None] = {}  # symbol -> stoploss price
        try:
            ft = FreqtradeClient(base_url=settings.freqtrade_url)
            status_data = await ft.get_status()
            if FreqtradeClient.is_success(status_data):
                # status returns list of open trades with stoploss info
                trades = status_data if isinstance(status_data, list) else status_data.get("result", [])
                for trade in trades:
                    if isinstance(trade, dict):
                        pair = trade.get("pair", "")
                        stop_loss = trade.get("stop_loss", None) or trade.get("stoploss", None)
                        stop_loss_abs = trade.get("stop_loss_abs", None)
                        exchange_stops[pair] = stop_loss_abs or stop_loss
        except Exception as inner_e:
            logger.debug("Could not fetch exchange stops from Freqtrade: %s", inner_e)

        # Merge exchange stops into positions and detect discrepancies
        overall_reason_codes = list(result.reason_codes)
        positions_out = []
        for p in result.positions:
            ft_stop = exchange_stops.get(p.symbol)
            actual_exchange_stop = ft_stop if ft_stop is not None else p.stops.exchange_protective_stop
            reason_codes = list(p.reason_codes)

            # Detect discrepancy between computed stop and actual exchange stop
            if ft_stop is not None and p.stops.exchange_protective_stop is not None:
                diff_pct = abs(ft_stop - p.stops.exchange_protective_stop) / p.entry_price * 100
                if diff_pct > 0.5:  # More than 0.5% discrepancy
                    reason_codes.append("exchange_stop_discrepancy")
                    if "stop_discrepancy_detected" not in overall_reason_codes:
                        overall_reason_codes.append("stop_discrepancy_detected")

            positions_out.append({
                "position_id": p.position_id, "symbol": p.symbol, "side": p.side,
                "entry_price": p.entry_price, "current_price": p.current_price,
                "stops": {
                    "raw_structure_stop": p.stops.raw_structure_stop,
                    "last_known_good_stop": p.stops.last_known_good_stop,
                    "secure_runtime_stop": p.stops.secure_runtime_stop,
                    "exchange_protective_stop": actual_exchange_stop,
                    "volatility_locked": p.stops.volatility_locked,
                },
                "stop_update_allowed": p.stop_update_allowed,
                "reason_codes": reason_codes,
            })

        state = result.state
        if "stop_discrepancy_detected" in overall_reason_codes and state == "healthy":
            state = "warning"

        return {
            "state": state,
            "reason_codes": overall_reason_codes,
            "available_actions": [{"type": "refresh_all", "enabled": True, "label": "刷新全部止损"}],
            "positions": positions_out,
            "volatility_locks": result.volatility_locks,
        }
    except Exception as e:
        logger.exception("[stop-protection] StopProtectionService unavailable: %s", e)
        return StopProtectionResponse(
            state="data_source_unavailable",
            reason_codes=["data_source_unavailable", type(e).__name__],
            available_actions=[],
            positions=[],
            volatility_locks=[],
        ).model_dump()


@router.get("/volatility-locks")
async def get_volatility_locks():
    return {"locks": [], "state": "healthy", "reason_codes": []}


@router.get("/circuit-breakers", response_model=CircuitBreakersResponse)
async def get_circuit_breakers(db: Session = Depends(get_db)):
    try:
        from app.domain.circuit_breaker import CircuitBreakerEvent

        # Query circuit breaker events from DB
        cb_event_types = [
            "emergency_stop", "daily_loss_lock", "weekly_loss_lock",
            "kill_switch", "manual_force_close",
        ]
        stmt = (
            select(CircuitBreakerEvent)
            .where(CircuitBreakerEvent.event_type.in_(cb_event_types))
            .order_by(CircuitBreakerEvent.created_at.desc())
            .limit(50)
        )
        events = list(db.scalars(stmt).all())

        records = [
            CircuitBreakerRecord(
                id=str(ev.id),
                type=ev.event_type,
                account_id=ev.account_id or "default",
                strategy_id=ev.strategy_id or "",
                reason_codes=ev.reason_codes if isinstance(ev.reason_codes, list) else list(ev.reason_codes.values()) if isinstance(ev.reason_codes, dict) else [],
                related_command_id=str(ev.related_command_id) if ev.related_command_id else None,
                related_reconciliation_id=str(ev.related_reconciliation_id) if ev.related_reconciliation_id else None,
                created_at=ev.created_at,
            )
            for ev in events
        ]

        # Determine state based on unresolved breakers
        unresolved = [ev for ev in events if not ev.resolved]
        state = "tripped" if unresolved else "healthy"

        return CircuitBreakersResponse(
            state=state,
            reason_codes=[ev.event_type for ev in unresolved[:5]],
            records=records,
            total_count=len(records),
        ).model_dump()
    except Exception as e:
        logger.exception("[circuit-breakers] DB query failed: %s", e)
        return CircuitBreakersResponse(
            state="data_source_unavailable",
            reason_codes=["data_source_unavailable", type(e).__name__],
            records=[],
            total_count=0,
        ).model_dump()


@router.get("/emergency-stop", include_in_schema=False)
@router.post("/emergency-stop", include_in_schema=False)
async def emergency_stop_deprecated():
    raise HTTPException(status_code=410, detail="deprecated, use POST /api/v2/emergency/stop")


@router.post("/block-new-entries")
async def block_new_entries(payload: dict | None = None):
    try:
        reason = (payload or {}).get("reason", "manual")
        locks = AccountRiskFirewall.activate_manual_block(reason=reason)
        return {"status": "blocked", "active_locks": locks, "reason_codes": []}
    except Exception as e:
        logger.exception("[block-new-entries] failed: %s", e)
        return {"status": "failed", "active_locks": [], "reason_codes": [type(e).__name__]}


@router.post("/unblock")
async def unblock():
    try:
        locks = AccountRiskFirewall.deactivate_manual_block()
        return {"status": "unblocked", "active_locks": locks, "reason_codes": []}
    except Exception as e:
        logger.exception("[unblock] failed: %s", e)
        return {"status": "failed", "active_locks": [], "reason_codes": [type(e).__name__]}


@router.get("/rules", response_model=RiskRulesResponse)
async def get_risk_rules(db: Session = Depends(get_db)):
    svc = RiskRulesService()
    r = svc.get_effective(db)
    return RiskRulesResponse(
        daily_loss_limit=r.daily_loss_limit,
        weekly_loss_limit=r.weekly_loss_limit,
        consecutive_losses_limit=r.consecutive_losses_limit,
        max_drawdown=r.max_drawdown,
        correlation_threshold=r.correlation_threshold,
        kill_switch={"threshold": r.kill_switch_threshold, "active": r.kill_switch_active},
    )


@router.post("/circuit-breakers/{event_id}/resolve", response_model=ResolveResponse)
async def resolve_circuit_breaker(event_id: str, db: Session = Depends(get_db)):
    from app.services.circuit_breaker_repository import CircuitBreakerRepository

    repo = CircuitBreakerRepository(db)
    evt = repo.get(event_id)
    if evt is None:
        return ResolveResponse(status="not_found", resolved_event_id=event_id, reason_codes=["event_not_found"])
    if evt.event_type in ("kill_switch", "emergency_stop"):
        return JSONResponse(
            content=ResolveResponse(
                status="rejected", resolved_event_id=event_id,
                reason_codes=["cannot_resolve_kill_switch"],
            ).model_dump(),
            status_code=409,
        )
    if evt.resolved:
        return ResolveResponse(status="already_resolved", resolved_event_id=event_id, reason_codes=[])
    repo.mark_resolved(event_id)
    return ResolveResponse(status="resolved", resolved_event_id=event_id, reason_codes=[])
