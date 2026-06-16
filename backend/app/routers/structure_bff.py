"""Structure BFF — Matrix + Shadow Windows + MTF Guard"""
import logging

from fastapi import APIRouter, Depends, Path, Query
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.database import get_db

from app.schemas.structure_bff import (
    StructureMatrixResponse,
    ShadowWindowsResponse, ShadowWindow,
)
from app.schemas.common import AvailableAction

router = APIRouter(prefix="/api/structure", tags=["structure-bff"])
logger = logging.getLogger(__name__)


# ── Shared service singletons (lazy-init) ─────────────────────────

_shadow_window_service = None
_mtf_guard_service = None


def _get_shadow_window_service():
    global _shadow_window_service
    if _shadow_window_service is None:
        from app.services.shadow_window import ShadowWindowService
        _shadow_window_service = ShadowWindowService()
    return _shadow_window_service


def _get_mtf_guard_service():
    global _mtf_guard_service
    if _mtf_guard_service is None:
        from app.services.mtf_temporal_guard import MTFTemporalGuardService
        _mtf_guard_service = MTFTemporalGuardService()
    return _mtf_guard_service


def _get_redis_store():
    from app.services.runtime_redis_store import RuntimeRedisStore
    from app.config import settings
    return RuntimeRedisStore(redis_url=settings.redis_url)


# ── Endpoints ────────────────────────────────────────────────────

@router.get("/matrix", response_model=StructureMatrixResponse)
async def get_structure_matrix(symbol: str = Query(default="BTC/USDT")):
    try:
        from app.services.structure_matrix_service import StructureMatrixService
        store = _get_redis_store()
        svc = StructureMatrixService(redis_store=store)
        result = await svc.get_matrix(symbol)
        return {
            "state": result.state,
            "reason_codes": result.reason_codes,
            "available_actions": [{"type": "refresh_structure", "enabled": True, "label": "刷新结构数据"}],
            "symbol": result.symbol,
            "base_timeframe": result.base_timeframe,
            "rows": [
                {
                    "timeframe": row.timeframe,
                    "cells": {k: {
                        "zone_type": c.zone_type, "status": c.status,
                        "current_strength": c.current_strength, "filled_ratio": c.filled_ratio,
                        "temporary_violation": c.temporary_violation, "action": c.action,
                        "reason_codes": c.reason_codes,
                    } for k, c in row.cells.items()},
                } for row in result.rows
            ],
        }
    except Exception as e:
        logger.exception("[structure-matrix] StructureMatrixService unavailable: %s", e)
        return StructureMatrixResponse(
            state="data_source_unavailable",
            reason_codes=["data_source_unavailable", type(e).__name__],
            available_actions=[],
            symbol=symbol,
            base_timeframe=None,
            rows=[],
        ).model_dump()


@router.get("/shadow-windows", response_model=ShadowWindowsResponse)
async def get_shadow_windows(symbol: str = Query(default="BTC/USDT")):
    """Return shadow window data from ShadowWindowService if available."""
    svc = _get_shadow_window_service()
    windows = svc.get_all_windows(symbol=symbol)

    if not windows:
        # No active windows — return empty data
        return ShadowWindowsResponse(
            state="healthy",
            reason_codes=[],
            symbol=symbol,
            windows=[],
        ).model_dump()

    overall_state = "healthy"
    overall_reasons: list[str] = []
    shadow_list: list[ShadowWindow] = []

    for w in windows:
        violation_type = None
        status = w.state.value
        reasons: list[str] = list(w.reason_codes)

        if w.state.value == "violation":
            violation_type = "temporary"
            overall_state = "warning"
            reason_code = f"{w.slow_timeframe}_shadow_temporary_violation"
            if reason_code not in overall_reasons:
                overall_reasons.append(reason_code)
        elif w.state.value == "active":
            reasons.append("shadow_intact")

        shadow_list.append(ShadowWindow(
            timeframe=w.slow_timeframe,
            zone_type=w.zone_type,
            status=status,
            violation_type=violation_type,
            reason_codes=reasons,
        ))

    return ShadowWindowsResponse(
        state=overall_state,
        reason_codes=overall_reasons,
        symbol=symbol,
        windows=shadow_list,
    ).model_dump()


@router.get("/mtf-guard/{strategy_id}/{symbol}")
async def get_mtf_guard_state(
    strategy_id: str = Path(..., description="Strategy ID"),
    symbol: str = Path(..., description="Trading pair, e.g. BTCUSDT"),
):
    """Get current MTF Guard state from Redis."""
    store = _get_redis_store()
    state = await store.read_mtf_guard_state(strategy_id, symbol)

    if state is None:
        return {
            "strategy_id": strategy_id,
            "symbol": symbol,
            "guard_state": "inactive",
            "action": "ignore",
            "reason_codes": ["no_active_guard"],
            "violation": {},
            "_source": "redis_miss",
        }

    return {
        "strategy_id": strategy_id,
        "symbol": symbol,
        **state,
        "_source": "redis",
    }


@router.get("/mtf-guard-events/{strategy_id}")
async def get_mtf_guard_events(
    strategy_id: str = Path(..., description="Strategy ID"),
    symbol: str = Query(default=None, description="Filter by symbol"),
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """Get historical MTF Guard events from mtf_guard_events table."""
    try:
        from app.domain.mtf_guard import MTFGuardEvent
        import uuid

        stmt = (
            select(MTFGuardEvent)
            .where(MTFGuardEvent.strategy_id == uuid.UUID(strategy_id))
            .order_by(MTFGuardEvent.created_at.desc())
            .limit(limit)
        )
        if symbol:
            stmt = stmt.where(MTFGuardEvent.symbol == symbol)

        events = list(db.scalars(stmt).all())

        return {
            "strategy_id": strategy_id,
            "events": [
                {
                    "id": str(ev.id),
                    "strategy_id": str(ev.strategy_id),
                    "symbol": ev.symbol,
                    "fast_timeframe": ev.fast_timeframe,
                    "slow_timeframe": ev.slow_timeframe,
                    "structure_type": ev.structure_type,
                    "guard_state": ev.guard_state,
                    "action": ev.action,
                    "htf_candle_closed": ev.htf_candle_closed,
                    "reason_codes": ev.reason_codes,
                    "created_at": ev.created_at.isoformat() if ev.created_at else None,
                }
                for ev in events
            ],
            "total": len(events),
        }
    except Exception as e:
        logger.exception("[mtf-guard-events] DB query failed: %s", e)
        return {
            "strategy_id": strategy_id,
            "events": [],
            "total": 0,
            "reason_codes": ["data_source_unavailable", type(e).__name__],
        }
