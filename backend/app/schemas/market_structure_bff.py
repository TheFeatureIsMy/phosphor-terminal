"""Market Structure BFF schemas"""
from __future__ import annotations
from pydantic import BaseModel, Field
from app.schemas.common import AvailableAction


class StructureZone(BaseModel):
    zone_id: str
    zone_type: str  # fvg / order_block / liquidity_pool
    direction: str  # bullish / bearish
    timeframe: str = "1h"
    price_top: float = 0
    price_bottom: float = 0
    status: str = "active"  # active / touched / mitigated / invalidated
    current_strength: float = 0
    filled_ratio: float = 0
    reason_codes: list[str] = Field(default_factory=list)


class LiquidityPoolResponse(BaseModel):
    pool_id: str
    pool_type: str  # equal_high / equal_low / swing_high / swing_low
    side: str  # buy_side / sell_side
    price_level: float = 0
    current_strength: float = 0
    status: str = "active"
    touched_count: int = 0


class StructureEvent(BaseModel):
    event_id: str
    event_type: str  # bos / choch / sweep / fvg_fill
    direction: str = ""
    price: float = 0
    timeframe: str = ""
    timestamp: str = ""


class MarketStructureResponse(BaseModel):
    state: str = "healthy"
    reason_codes: list[str] = Field(default_factory=list)
    available_actions: list[AvailableAction] = Field(default_factory=list)
    symbol: str = ""
    timeframe: str = "5m"
    market_regime: str = "unknown"
    structure_score: float = 0
    zones: list[StructureZone] = Field(default_factory=list)
    liquidity_pools: list[LiquidityPoolResponse] = Field(default_factory=list)
    events: list[StructureEvent] = Field(default_factory=list)
    premium_discount: str = ""  # premium / discount / equilibrium
