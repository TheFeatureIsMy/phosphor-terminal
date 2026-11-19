"""Risk BFF — Overview + Stop Protection + Circuit Breakers"""
import json
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from pydantic import BaseModel as BaseModel
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
from app.models.user import User
from app.security.deps import get_current_tenant_id, require_superuser

from app.services.account_risk_firewall import AccountRiskFirewall
from app.services.risk_rules_service import RiskRulesService
from app.utils import hash_string

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
                active_locks=AccountRiskFirewall.current_locks(),
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
                active_locks=AccountRiskFirewall.current_locks(),
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
            active_locks=AccountRiskFirewall.current_locks(),
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
async def get_volatility_locks(symbol: str | None = Query(None)):
    try:
        from app.services.volatility_lock_service import VolatilityLockService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.config import settings

        store = RuntimeRedisStore(redis_url=settings.redis_url)
        svc = VolatilityLockService(redis_store=store)
        locks = await svc.list_locks(symbol)
        active = [lk for lk in locks if lk.locked]
        return {
            "state": "locked" if active else "healthy",
            "reason_codes": [c for lk in active for c in lk.reason_codes],
            "locks": [
                {
                    "symbol": lk.symbol, "timeframe": lk.timeframe, "locked": lk.locked,
                    "lock_type": lk.lock_type, "trigger_value": lk.trigger_value,
                    "threshold_value": lk.threshold_value, "reason_codes": lk.reason_codes,
                }
                for lk in locks
            ],
        }
    except Exception as e:
        logger.exception("[volatility-locks] failed: %s", e)
        return {"state": "data_source_unavailable", "reason_codes": [type(e).__name__], "locks": []}


@router.get("/exchange-protective-stops")
async def get_exchange_protective_stops():
    """Exchange-side protective stops aggregated from Freqtrade open trades."""
    try:
        from app.services.freqtrade_client import FreqtradeClient
        from app.config import settings

        ft = FreqtradeClient(base_url=settings.freqtrade_url)
        status_data = await ft.get_status()
        if not FreqtradeClient.is_success(status_data):
            return {
                "state": "data_source_unavailable",
                "reason_codes": ["freqtrade_unavailable"],
                "available_actions": [],
                "stops": [],
            }
        trades = status_data if isinstance(status_data, list) else status_data.get("result", [])
        stops = []
        for trade in trades:
            if not isinstance(trade, dict):
                continue
            stop_abs = trade.get("stop_loss_abs") or trade.get("stop_loss")
            stops.append({
                "symbol": trade.get("pair", ""),
                "exchange_protective_stop": stop_abs,
                "current_rate": trade.get("current_rate"),
                "reason_codes": [] if stop_abs is not None else ["stop_not_available"],
            })
        return {
            "state": "healthy",
            "reason_codes": [],
            "available_actions": [],
            "stops": stops,
        }
    except Exception as e:
        logger.exception("[exchange-protective-stops] failed: %s", e)
        return {
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(e).__name__],
            "available_actions": [],
            "stops": [],
        }


async def _resolve_position_symbol(position_id: str) -> tuple[str | None, dict | None]:
    """Resolve a position's symbol via StopProtectionService; returns (symbol, error_body)."""
    from app.services.stop_protection_service import StopProtectionService
    from app.services.runtime_redis_store import RuntimeRedisStore
    from app.config import settings

    store = RuntimeRedisStore(redis_url=settings.redis_url)
    svc = StopProtectionService(redis_store=store)
    pos = await svc.refresh_position(position_id)
    if pos is None:
        return None, {
            "state": "data_source_unavailable",
            "reason_codes": ["position_not_found"],
            "available_actions": [],
        }
    return pos.symbol, None


@router.post("/stop-protection/{position_id}/refresh")
async def refresh_stop_protection(position_id: str):
    """Refresh stop levels for a single position."""
    try:
        from app.services.stop_protection_service import StopProtectionService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.config import settings

        store = RuntimeRedisStore(redis_url=settings.redis_url)
        svc = StopProtectionService(redis_store=store)
        pos = await svc.refresh_position(position_id)
        if pos is None:
            return JSONResponse(
                content={"state": "data_source_unavailable",
                         "reason_codes": ["position_not_found"], "available_actions": []},
                status_code=404,
            )
        return {
            "state": "healthy",
            "reason_codes": pos.reason_codes,
            "available_actions": [
                {"type": "force_lock", "enabled": True, "label": "强制波动率锁定"},
                {"type": "release_lock", "enabled": True, "label": "解除锁定"},
            ],
            "position": {
                "position_id": pos.position_id, "symbol": pos.symbol, "side": pos.side,
                "entry_price": pos.entry_price, "current_price": pos.current_price,
                "stops": {
                    "raw_structure_stop": pos.stops.raw_structure_stop,
                    "last_known_good_stop": pos.stops.last_known_good_stop,
                    "secure_runtime_stop": pos.stops.secure_runtime_stop,
                    "exchange_protective_stop": pos.stops.exchange_protective_stop,
                    "volatility_locked": pos.stops.volatility_locked,
                },
                "stop_update_allowed": pos.stop_update_allowed,
            },
        }
    except Exception as e:
        logger.exception("[stop-protection/refresh] failed: %s", e)
        return {"state": "data_source_unavailable",
                "reason_codes": ["data_source_unavailable", type(e).__name__],
                "available_actions": []}


@router.post("/stop-protection/{position_id}/force-lock")
async def force_lock_position(position_id: str):
    """Manually force a volatility lock on the position's symbol."""
    try:
        from app.services.volatility_lock_service import VolatilityLockService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.config import settings

        symbol, err = await _resolve_position_symbol(position_id)
        if err is not None:
            return JSONResponse(content=err, status_code=404)

        store = RuntimeRedisStore(redis_url=settings.redis_url)
        svc = VolatilityLockService(redis_store=store)
        lock = await svc.force_lock(symbol, reason="manual_force_lock")
        return {
            "state": "locked",
            "reason_codes": lock.reason_codes,
            "available_actions": [{"type": "release_lock", "enabled": True, "label": "解除锁定"}],
            "symbol": symbol,
            "position_id": position_id,
        }
    except Exception as e:
        logger.exception("[stop-protection/force-lock] failed: %s", e)
        return {"state": "failed", "reason_codes": [type(e).__name__], "available_actions": []}


@router.post("/stop-protection/{position_id}/release-lock")
async def release_lock_position(position_id: str):
    """Release the volatility lock on the position's symbol."""
    try:
        from app.services.volatility_lock_service import VolatilityLockService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.config import settings

        symbol, err = await _resolve_position_symbol(position_id)
        if err is not None:
            return JSONResponse(content=err, status_code=404)

        store = RuntimeRedisStore(redis_url=settings.redis_url)
        svc = VolatilityLockService(redis_store=store)
        await svc.release(symbol)
        return {
            "state": "healthy",
            "reason_codes": [],
            "available_actions": [{"type": "force_lock", "enabled": True, "label": "强制波动率锁定"}],
            "symbol": symbol,
            "position_id": position_id,
        }
    except Exception as e:
        logger.exception("[stop-protection/release-lock] failed: %s", e)
        return {"state": "failed", "reason_codes": [type(e).__name__], "available_actions": []}


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
                resolved=ev.resolved,
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


@router.post("/block-new-entries")
async def block_new_entries(payload: dict | None = None, db: Session = Depends(get_db)):
    try:
        reason = (payload or {}).get("reason", "manual")
        locks = AccountRiskFirewall.activate_manual_block(
            reason=reason, db=db, updated_by="api:risk/block-new-entries",
        )
        return {"status": "blocked", "active_locks": locks, "reason_codes": []}
    except Exception as e:
        logger.exception("[block-new-entries] failed: %s", e)
        return {"status": "failed", "active_locks": [], "reason_codes": [type(e).__name__]}


@router.post("/unblock")
async def unblock(db: Session = Depends(get_db)):
    try:
        locks = AccountRiskFirewall.deactivate_manual_block(
            db=db, updated_by="api:risk/unblock",
        )
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


# --- Risk Rules Update ---

class RiskRulesUpdateRequest(BaseModel):
    daily_loss_limit: float | None = None
    weekly_loss_limit: float | None = None
    consecutive_losses_limit: int | None = None
    max_drawdown: float | None = None
    correlation_threshold: float | None = None
    kill_switch_active: bool | None = None


@router.put("/rules", response_model=RiskRulesResponse)
def update_risk_rules(
    body: RiskRulesUpdateRequest,
    db: Session = Depends(get_db),
    _admin: User | None = Depends(require_superuser),
    tenant_raw: str | None = Depends(get_current_tenant_id),
):
    """Update the active risk policy's rule thresholds (admin only)."""
    from app.domain.risk import RiskPolicy, RiskPolicyVersion
    from datetime import datetime, timezone

    try:
        tenant_id = int(tenant_raw) if tenant_raw is not None else None
    except (TypeError, ValueError):
        tenant_id = None

    # Find or create the tenant's active policy.
    query = db.query(RiskPolicyVersion).filter(RiskPolicyVersion.status == "active")
    if tenant_id is None:
        query = query.filter(RiskPolicyVersion.tenant_id.is_(None))
    else:
        query = query.filter(RiskPolicyVersion.tenant_id == tenant_id)
    active_version = query.order_by(RiskPolicyVersion.created_at.desc()).first()

    if active_version is None:
        # Create a default policy + version for this tenant.
        policy = RiskPolicy(
            name="default_risk_policy",
            policy_type="global",
            status="active",
            tenant_id=tenant_id,
        )
        db.add(policy)
        db.flush()

        policy_json = {}
        active_version = RiskPolicyVersion(
            risk_policy_id=policy.id,
            version_no=1,
            status="active",
            policy_json=policy_json,
            policy_hash=hash_string(json.dumps(policy_json, sort_keys=True)),
            created_by="web",
            tenant_id=tenant_id,
        )
        db.add(active_version)
        db.flush()

    # Update fields
    pj = dict(active_version.policy_json or {})
    if body.daily_loss_limit is not None:
        pj["max_daily_loss_pct"] = body.daily_loss_limit / 100.0
    if body.weekly_loss_limit is not None:
        pj["max_weekly_loss_pct"] = body.weekly_loss_limit / 100.0
    if body.consecutive_losses_limit is not None:
        pj["max_consecutive_losses"] = body.consecutive_losses_limit
    if body.max_drawdown is not None:
        pj["max_drawdown_pct"] = body.max_drawdown / 100.0
    if body.correlation_threshold is not None:
        pj["correlation_threshold"] = body.correlation_threshold
    if body.kill_switch_active is not None:
        pj["kill_switch_active"] = body.kill_switch_active

    active_version.policy_json = pj
    # Keep the audit hash in sync with the content it claims to describe.
    active_version.policy_hash = hash_string(json.dumps(pj, sort_keys=True))
    db.commit()

    # Return updated rules
    svc = RiskRulesService()
    rules = svc.get_effective(db)
    return RiskRulesResponse(
        state="healthy",
        reason_codes=[],
        daily_loss_limit=rules.daily_loss_limit,
        weekly_loss_limit=rules.weekly_loss_limit,
        consecutive_losses_limit=rules.consecutive_losses_limit,
        max_drawdown=rules.max_drawdown,
        correlation_threshold=rules.correlation_threshold,
        kill_switch={"active": rules.kill_switch_active, "threshold": rules.kill_switch_threshold},
    )
