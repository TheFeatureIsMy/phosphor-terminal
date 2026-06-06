from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class StructureStatus(str, Enum):
    ACTIVE = "active"
    TOUCHED = "touched"
    MITIGATED = "mitigated"
    INVALIDATED = "invalidated"
    EXPIRED = "expired"


class PoolStatus(str, Enum):
    ACTIVE = "active"
    TOUCHED = "touched"
    SWEPT = "swept"
    INVALIDATED = "invalidated"
    EXPIRED = "expired"


class SweepState(str, Enum):
    NONE = "none"
    SWEEP_CANDIDATE = "sweep_candidate"
    RECLAIM_PENDING = "reclaim_pending"
    CONFIRMED_SWEEP = "confirmed_sweep"
    EXPIRED = "expired"
    INVALIDATED = "invalidated"


class MarketRegime(str, Enum):
    TREND_UP = "trend_up"
    TREND_DOWN = "trend_down"
    RANGE = "range"
    HIGH_VOLATILITY = "high_volatility"
    PANIC = "panic"
    NEWS_SHOCK = "news_shock"
    LIQUIDITY_VOID = "liquidity_void"
    UNKNOWN = "unknown"


class StructureDirection(str, Enum):
    BULLISH = "bullish"
    BEARISH = "bearish"


@dataclass
class SwingPoint:
    price: float
    index: int
    candle_time: Optional[datetime] = None
    is_high: bool = True
    strength: int = 1  # how many candles on each side confirm it


@dataclass
class LiquidityPool:
    pool_id: str
    pool_type: str  # equal_high, equal_low, swing_high, swing_low, prev_day_high, etc.
    side: str  # buy_side, sell_side
    price_level: float
    initial_strength: float = 0.8
    current_strength: float = 0.8
    status: PoolStatus = PoolStatus.ACTIVE
    touched_count: int = 0
    timeframe: str = "5m"
    candle_time: Optional[datetime] = None
    swept_at: Optional[datetime] = None


@dataclass
class LiquiditySweep:
    sweep_id: str
    pool: LiquidityPool
    state: SweepState = SweepState.NONE
    sweep_type: str = ""  # sell_side_liquidity_sweep, buy_side_liquidity_sweep
    swept_level: float = 0.0
    sweep_low: float = 0.0  # for sell-side: lowest price during sweep
    sweep_high: float = 0.0  # for buy-side: highest price during sweep
    reclaim_price: float = 0.0
    volume_zscore: float = 0.0
    confidence: float = 0.0
    candle_index: int = 0


@dataclass
class FairValueGap:
    fvg_id: str
    direction: StructureDirection
    price_top: float
    price_bottom: float
    initial_strength: float = 0.8
    current_strength: float = 0.8
    filled_ratio: float = 0.0
    status: StructureStatus = StructureStatus.ACTIVE
    touched_count: int = 0
    timeframe: str = "5m"
    candle_index: int = 0
    candle_time: Optional[datetime] = None
    age_bars: int = 0
    low_tf_violation_count: int = 0


@dataclass
class OrderBlock:
    ob_id: str
    direction: StructureDirection
    price_top: float
    price_bottom: float
    initial_strength: float = 0.8
    current_strength: float = 0.8
    status: StructureStatus = StructureStatus.ACTIVE
    touched_count: int = 0
    timeframe: str = "5m"
    candle_index: int = 0
    candle_time: Optional[datetime] = None
    age_bars: int = 0
    volume_ratio: float = 1.0  # volume relative to average


@dataclass
class StructureBreak:
    break_type: str  # bos, choch
    direction: StructureDirection
    price_level: float
    broken_swing: SwingPoint
    candle_index: int = 0
    candle_time: Optional[datetime] = None
    confirmed: bool = False


@dataclass
class StructureSnapshot:
    """Complete structure state at a point in time."""
    market_regime: MarketRegime = MarketRegime.UNKNOWN
    swing_highs: list[SwingPoint] = field(default_factory=list)
    swing_lows: list[SwingPoint] = field(default_factory=list)
    liquidity_pools: list[LiquidityPool] = field(default_factory=list)
    active_sweeps: list[LiquiditySweep] = field(default_factory=list)
    fvg_zones: list[FairValueGap] = field(default_factory=list)
    order_blocks: list[OrderBlock] = field(default_factory=list)
    structure_breaks: list[StructureBreak] = field(default_factory=list)
    structure_score: int = 0
    structure_direction: Optional[StructureDirection] = None
