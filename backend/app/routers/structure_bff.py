"""Structure BFF — Matrix + Shadow Windows"""
import logging

from fastapi import APIRouter, Query

from app.schemas.structure_bff import (
    StructureMatrixResponse, MatrixRow, MatrixCell,
    ShadowWindowsResponse, ShadowWindow,
)
from app.schemas.common import AvailableAction

router = APIRouter(prefix="/api/structure", tags=["structure-bff"])
logger = logging.getLogger(__name__)


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


def _mock_shadow_windows(symbol: str) -> dict:
    return ShadowWindowsResponse(
        state="warning",
        reason_codes=["1h_shadow_temporary_violation"],
        symbol=symbol,
        windows=[
            ShadowWindow(timeframe="1h", zone_type="order_block", status="warning", violation_type="temporary", reason_codes=["shadow_low_violated_ob_bottom"]),
            ShadowWindow(timeframe="4h", zone_type="order_block", status="active", reason_codes=["shadow_intact"]),
        ],
    ).model_dump()


@router.get("/matrix", response_model=StructureMatrixResponse)
async def get_structure_matrix(symbol: str = Query(default="BTC/USDT")):
    try:
        from app.services.structure_matrix_service import StructureMatrixService
        from app.services.runtime_redis_store import RuntimeRedisStore
        from app.config import settings
        store = RuntimeRedisStore(redis_url=settings.redis_url)
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
    return _mock_shadow_windows(symbol)
