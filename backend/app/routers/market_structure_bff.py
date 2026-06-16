"""Market Structure BFF — Zones + Liquidity Pools + Events + Regime"""
import logging

from fastapi import APIRouter, Query

from app.schemas.market_structure_bff import MarketStructureResponse

router = APIRouter(prefix="/api/structure", tags=["market-structure-bff"])
logger = logging.getLogger(__name__)


@router.get("/market-view", response_model=MarketStructureResponse)
async def get_market_view(symbol: str = Query(default="BTC/USDT"), timeframe: str = Query(default="5m")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_market_view(symbol=symbol, timeframe=timeframe)
    except Exception as e:
        logger.exception("[market-view] StructureEngine unavailable: %s", e)
        return MarketStructureResponse(
            state="data_source_unavailable",
            reason_codes=["data_source_unavailable", type(e).__name__],
            available_actions=[],
            symbol=symbol,
            timeframe=timeframe,
            market_regime=None,
            structure_score=0,
            zones=[],
            liquidity_pools=[],
            events=[],
            premium_discount=None,
        ).model_dump()


@router.get("/zones")
async def get_zones(symbol: str = Query(default="BTC/USDT"), timeframe: str = Query(default="1h")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_zones(symbol=symbol, timeframe=timeframe)
    except Exception as e:
        logger.exception("[zones] StructureEngine unavailable: %s", e)
        return {"state": "data_source_unavailable", "reason_codes": ["data_source_unavailable", type(e).__name__], "zones": []}


@router.get("/liquidity-pools")
async def get_liquidity_pools(symbol: str = Query(default="BTC/USDT")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_liquidity_pools(symbol=symbol)
    except Exception as e:
        logger.exception("[liquidity-pools] StructureEngine unavailable: %s", e)
        return {"state": "data_source_unavailable", "reason_codes": ["data_source_unavailable", type(e).__name__], "liquidity_pools": []}


@router.get("/events")
async def get_structure_events(symbol: str = Query(default="BTC/USDT"), timeframe: str = Query(default="1h")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_events(symbol=symbol, timeframe=timeframe)
    except Exception as e:
        logger.exception("[events] StructureEngine unavailable: %s", e)
        return {"state": "data_source_unavailable", "reason_codes": ["data_source_unavailable", type(e).__name__], "events": []}


@router.get("/market-regime")
async def get_market_regime(symbol: str = Query(default="BTC/USDT"), timeframe: str = Query(default="1h")):
    try:
        from app.services.structure.engine import StructureEngine
        engine = StructureEngine()
        return await engine.get_regime(symbol=symbol, timeframe=timeframe)
    except Exception as e:
        logger.exception("[market-regime] StructureEngine unavailable: %s", e)
        return {
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(e).__name__],
            "symbol": symbol,
            "timeframe": timeframe,
            "market_regime": None,
            "structure_score": 0,
            "premium_discount": None,
        }
