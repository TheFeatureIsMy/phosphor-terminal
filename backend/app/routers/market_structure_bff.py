"""Market Structure BFF — Zones + Liquidity Pools + Events + Regime"""
import logging

from fastapi import APIRouter, Query

from app.schemas.market_structure_bff import (
    MarketStructureResponse, StructureZone,
    LiquidityPoolResponse, StructureEvent,
)
from app.schemas.common import AvailableAction

router = APIRouter(prefix="/api/structure", tags=["market-structure-bff"])
logger = logging.getLogger(__name__)


def _mock_zones() -> list[dict]:
    return [
        StructureZone(zone_id="zone-001", zone_type="fvg", direction="bullish", timeframe="1h", price_top=62800, price_bottom=62500, status="active", current_strength=0.82, filled_ratio=0.25, reason_codes=["unfilled_imbalance"]).model_dump(),
        StructureZone(zone_id="zone-002", zone_type="fvg", direction="bearish", timeframe="15m", price_top=63200, price_bottom=63050, status="touched", current_strength=0.45, filled_ratio=0.72, reason_codes=["partially_filled"]).model_dump(),
        StructureZone(zone_id="zone-003", zone_type="order_block", direction="bullish", timeframe="4h", price_top=61800, price_bottom=61500, status="active", current_strength=0.91, filled_ratio=0.0, reason_codes=["strong_reaction"]).model_dump(),
        StructureZone(zone_id="zone-004", zone_type="liquidity_pool", direction="bearish", timeframe="1h", price_top=63500, price_bottom=63450, status="active", current_strength=0.68, filled_ratio=0.0, reason_codes=["equal_highs_cluster"]).model_dump(),
    ]


def _mock_liquidity_pools() -> list[dict]:
    return [
        LiquidityPoolResponse(pool_id="lp-001", pool_type="equal_high", side="buy_side", price_level=63500, current_strength=0.75, status="active", touched_count=0).model_dump(),
        LiquidityPoolResponse(pool_id="lp-002", pool_type="swing_low", side="sell_side", price_level=61200, current_strength=0.88, status="active", touched_count=1).model_dump(),
        LiquidityPoolResponse(pool_id="lp-003", pool_type="equal_low", side="sell_side", price_level=60800, current_strength=0.62, status="active", touched_count=0).model_dump(),
    ]


def _mock_events() -> list[dict]:
    return [
        StructureEvent(event_id="evt-001", event_type="bos", direction="bullish", price=62650, timeframe="1h", timestamp="2026-06-06T08:15:00Z").model_dump(),
        StructureEvent(event_id="evt-002", event_type="choch", direction="bearish", price=63100, timeframe="15m", timestamp="2026-06-06T09:30:00Z").model_dump(),
        StructureEvent(event_id="evt-003", event_type="sweep", direction="bearish", price=63520, timeframe="1h", timestamp="2026-06-06T10:00:00Z").model_dump(),
    ]


def _mock_market_view(symbol: str, timeframe: str) -> dict:
    return MarketStructureResponse(
        state="healthy",
        reason_codes=["trend_aligned", "htf_support_intact"],
        available_actions=[
            AvailableAction(type="refresh_structure", enabled=True, label="刷新结构数据"),
            AvailableAction(type="toggle_timeframe", enabled=True, label="切换时间周期"),
        ],
        symbol=symbol,
        timeframe=timeframe,
        market_regime="trend_up",
        structure_score=76,
        zones=[
            StructureZone(zone_id="zone-001", zone_type="fvg", direction="bullish", timeframe="1h", price_top=62800, price_bottom=62500, status="active", current_strength=0.82, filled_ratio=0.25, reason_codes=["unfilled_imbalance"]),
            StructureZone(zone_id="zone-002", zone_type="fvg", direction="bearish", timeframe="15m", price_top=63200, price_bottom=63050, status="touched", current_strength=0.45, filled_ratio=0.72, reason_codes=["partially_filled"]),
            StructureZone(zone_id="zone-003", zone_type="order_block", direction="bullish", timeframe="4h", price_top=61800, price_bottom=61500, status="active", current_strength=0.91, filled_ratio=0.0, reason_codes=["strong_reaction"]),
            StructureZone(zone_id="zone-004", zone_type="liquidity_pool", direction="bearish", timeframe="1h", price_top=63500, price_bottom=63450, status="active", current_strength=0.68, filled_ratio=0.0, reason_codes=["equal_highs_cluster"]),
        ],
        liquidity_pools=[
            LiquidityPoolResponse(pool_id="lp-001", pool_type="equal_high", side="buy_side", price_level=63500, current_strength=0.75, status="active", touched_count=0),
            LiquidityPoolResponse(pool_id="lp-002", pool_type="swing_low", side="sell_side", price_level=61200, current_strength=0.88, status="active", touched_count=1),
            LiquidityPoolResponse(pool_id="lp-003", pool_type="equal_low", side="sell_side", price_level=60800, current_strength=0.62, status="active", touched_count=0),
        ],
        events=[
            StructureEvent(event_id="evt-001", event_type="bos", direction="bullish", price=62650, timeframe="1h", timestamp="2026-06-06T08:15:00Z"),
            StructureEvent(event_id="evt-002", event_type="choch", direction="bearish", price=63100, timeframe="15m", timestamp="2026-06-06T09:30:00Z"),
            StructureEvent(event_id="evt-003", event_type="sweep", direction="bearish", price=63520, timeframe="1h", timestamp="2026-06-06T10:00:00Z"),
        ],
        premium_discount="discount",
    ).model_dump()


@router.get("/market-view", response_model=MarketStructureResponse)
async def get_market_view(symbol: str = Query(default="BTC/USDT"), timeframe: str = Query(default="5m")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_market_view(symbol=symbol, timeframe=timeframe)
    except Exception as e:
        logger.warning(f"[market-view] StructureEngine unavailable, mock fallback: {e}")
        data = _mock_market_view(symbol, timeframe)
        data["_mock"] = True
        return data


@router.get("/zones")
async def get_zones(symbol: str = Query(default="BTC/USDT"), timeframe: str = Query(default="1h")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_zones(symbol=symbol, timeframe=timeframe)
    except Exception as e:
        logger.warning(f"[zones] StructureEngine unavailable, mock fallback: {e}")
        return {"state": "healthy", "reason_codes": [], "zones": _mock_zones(), "_mock": True}


@router.get("/liquidity-pools")
async def get_liquidity_pools(symbol: str = Query(default="BTC/USDT")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_liquidity_pools(symbol=symbol)
    except Exception as e:
        logger.warning(f"[liquidity-pools] StructureEngine unavailable, mock fallback: {e}")
        return {"state": "healthy", "reason_codes": [], "liquidity_pools": _mock_liquidity_pools(), "_mock": True}


@router.get("/events")
async def get_structure_events(symbol: str = Query(default="BTC/USDT"), timeframe: str = Query(default="1h")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_events(symbol=symbol, timeframe=timeframe)
    except Exception as e:
        logger.warning(f"[events] StructureEngine unavailable, mock fallback: {e}")
        return {"state": "healthy", "reason_codes": [], "events": _mock_events(), "_mock": True}


@router.get("/market-regime")
async def get_market_regime(symbol: str = Query(default="BTC/USDT"), timeframe: str = Query(default="1h")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_regime(symbol=symbol, timeframe=timeframe)
    except Exception as e:
        logger.warning(f"[market-regime] StructureEngine unavailable, mock fallback: {e}")
        return {
            "state": "healthy",
            "reason_codes": ["trend_aligned"],
            "symbol": symbol,
            "timeframe": timeframe,
            "market_regime": "trend_up",
            "structure_score": 76,
            "premium_discount": "discount",
            "_mock": True,
        }
