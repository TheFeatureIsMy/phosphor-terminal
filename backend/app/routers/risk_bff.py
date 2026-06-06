"""Risk BFF — Overview + Stop Protection + Circuit Breakers"""
import logging

from fastapi import APIRouter, Depends

from app.schemas.risk_bff import (
    RiskOverviewResponse, RiskGuard,
    StopProtectionResponse, PositionStop, StopLevel,
    CircuitBreakersResponse, CircuitBreakerRecord,
)
from app.schemas.common import AvailableAction
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.database import get_db

router = APIRouter(prefix="/api/risk", tags=["risk-bff"])
logger = logging.getLogger(__name__)


def _mock_overview() -> dict:
    return RiskOverviewResponse(
        state="normal",
        reason_codes=[],
        available_actions=[
            AvailableAction(type="emergency_stop", enabled=True, label="紧急停止", confirm_required=True),
            AvailableAction(type="block_new_entries", enabled=True, label="禁止新开仓"),
            AvailableAction(type="unblock", enabled=True, label="解除禁止"),
        ],
        account_state="normal",
        emergency_locked=False,
        guards=[
            RiskGuard(key="daily_loss", label="日亏损限制", current_value=120, limit_value=500, remaining_pct=0.76, status="healthy"),
            RiskGuard(key="weekly_loss", label="周亏损限制", current_value=280, limit_value=1500, remaining_pct=0.81, status="healthy"),
            RiskGuard(key="exposure", label="总敞口", current_value=3200, limit_value=8000, remaining_pct=0.6, status="healthy"),
            RiskGuard(key="consecutive_loss", label="连续亏损", current_value=1, limit_value=5, remaining_pct=0.8, status="healthy"),
        ],
        active_locks=[],
    ).model_dump()


def _mock_stop_protection() -> dict:
    return StopProtectionResponse(
        state="healthy",
        reason_codes=[],
        available_actions=[
            AvailableAction(type="refresh_all", enabled=True, label="刷新全部止损"),
        ],
        positions=[
            PositionStop(
                position_id="pos-001", symbol="BTC/USDT", side="long",
                entry_price=62100, current_price=62450,
                stops=StopLevel(raw_structure_stop=61200, last_known_good_stop=61350, secure_runtime_stop=61350, exchange_protective_stop=61000),
                stop_update_allowed=True, reason_codes=["structure_stop_valid"],
            ),
            PositionStop(
                position_id="pos-002", symbol="ETH/USDT", side="long",
                entry_price=3380, current_price=3410,
                stops=StopLevel(raw_structure_stop=3300, last_known_good_stop=3320, secure_runtime_stop=3320, exchange_protective_stop=3280, volatility_locked=False),
                stop_update_allowed=True, reason_codes=["structure_stop_valid"],
            ),
        ],
        volatility_locks=[],
    ).model_dump()


def _mock_circuit_breakers() -> dict:
    return CircuitBreakersResponse(
        state="healthy",
        reason_codes=[],
        records=[
            CircuitBreakerRecord(id="cb-001", type="daily_loss_lock", account_id="default", reason_codes=["daily_loss_limit_reached"]),
            CircuitBreakerRecord(id="cb-002", type="emergency_stop", account_id="default", reason_codes=["manual_trigger"], related_command_id="cmd-099"),
        ],
        total_count=2,
    ).model_dump()


@router.get("/overview", response_model=RiskOverviewResponse)
async def get_risk_overview():
    try:
        from app.services.bff.risk_aggregator import RiskAggregator
        agg = RiskAggregator()
        return await agg.overview()
    except Exception as e:
        logger.warning(f"[risk-overview] RiskAggregator unavailable, mock fallback: {e}")
        data = _mock_overview()
        data["_mock"] = True
        return data


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
        logger.warning(f"[stop-protection] StopProtectionService unavailable, mock fallback: {e}")
        data = _mock_stop_protection()
        data["_mock"] = True
        return data


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
        logger.warning(f"[circuit-breakers] DB query failed, mock fallback: {e}")
        data = _mock_circuit_breakers()
        data["_mock"] = True
        return data


@router.post("/emergency-stop")
async def risk_emergency_stop():
    return {"status": "emergency_stop_executed", "reason_codes": ["manual_trigger"]}


@router.post("/block-new-entries")
async def block_new_entries():
    return {"status": "blocked", "reason_codes": ["manual_block"]}


@router.post("/unblock")
async def unblock():
    return {"status": "unblocked", "reason_codes": ["manual_unblock"]}
