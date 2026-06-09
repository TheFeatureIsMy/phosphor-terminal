"""Structure BFF — Matrix + Shadow Windows + MTF Guard"""
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Query, Path

from app.schemas.structure_bff import (
    StructureMatrixResponse, MatrixRow, MatrixCell,
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


# ── Mock helpers ──────────────────────────────────────────────────

def _mock_matrix(symbol: str) -> dict:
    return StructureMatrixResponse(
        state="warning",
        reason_codes=["shadow_ob_temporary_violation"],
        available_actions=[
            AvailableAction(type="refresh_structure", enabled=True, label="刷新结构数据"),
        ],
        symbol=symbol,
        base_timeframe="5m",
        rows=[
            MatrixRow(timeframe="5m", cells={
                "bullish_ob": MatrixCell(zone_type="order_block", status="active", current_strength=0.78, action="allow"),
                "fvg": MatrixCell(zone_type="fvg", status="active", current_strength=0.65, filled_ratio=0.35, action="allow"),
            }),
            MatrixRow(timeframe="15m", cells={
                "bullish_ob": MatrixCell(zone_type="order_block", status="active", current_strength=0.82, action="allow"),
                "fvg": MatrixCell(zone_type="fvg", status="active", current_strength=0.71, filled_ratio=0.42, action="allow"),
            }),
            MatrixRow(timeframe="1h", cells={
                "bullish_ob": MatrixCell(zone_type="order_block", status="warning", current_strength=0.41, temporary_violation=True, action="reduce_size", reason_codes=["shadow_low_violated_ob_bottom"]),
                "fvg": MatrixCell(zone_type="fvg", status="active", current_strength=0.55, filled_ratio=0.85, action="reduce_size", reason_codes=["fvg_nearly_filled"]),
            }),
            MatrixRow(timeframe="4h", cells={
                "bullish_ob": MatrixCell(zone_type="order_block", status="active", current_strength=0.88, action="allow"),
                "fvg": MatrixCell(zone_type="fvg", status="active", current_strength=0.92, filled_ratio=0.12, action="allow"),
            }),
        ],
    ).model_dump()


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
        logger.warning(f"[structure-matrix] StructureMatrixService unavailable, mock fallback: {e}")
        data = _mock_matrix(symbol)
        data["_mock"] = True
        return data


@router.get("/shadow-windows", response_model=ShadowWindowsResponse)
async def get_shadow_windows(symbol: str = Query(default="BTC/USDT")):
    """Return shadow window data from ShadowWindowService if available."""
    svc = _get_shadow_window_service()
    windows = svc.get_all_windows(symbol=symbol)

    if not windows:
        # No active windows — return mock data as fallback
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
):
    """Get historical MTF Guard events (mock for now, DB integration pending)."""
    # TODO: Replace with real DB query from mtf_guard_events table
    now = datetime.now(timezone.utc)
    mock_events = [
        {
            "id": "evt_001",
            "strategy_id": strategy_id,
            "symbol": symbol or "BTC/USDT",
            "fast_timeframe": "5m",
            "slow_timeframe": "1h",
            "structure_type": "order_block",
            "guard_state": "temporary_violation",
            "action": "block_entry",
            "htf_candle_closed": False,
            "reason_codes": ["fast_tf_entered_htf_zone"],
            "created_at": now.isoformat(),
        },
        {
            "id": "evt_002",
            "strategy_id": strategy_id,
            "symbol": symbol or "BTC/USDT",
            "fast_timeframe": "5m",
            "slow_timeframe": "1h",
            "structure_type": "order_block",
            "guard_state": "confirmed",
            "action": "allow",
            "htf_candle_closed": True,
            "reason_codes": ["htf_close_reclaimed"],
            "created_at": now.isoformat(),
        },
    ]

    return {
        "strategy_id": strategy_id,
        "events": mock_events[:limit],
        "total": len(mock_events),
        "_mock": True,
    }
