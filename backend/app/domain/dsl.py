"""StrategyRuleDSL v2.5 — Pydantic type definitions and whitelists.

Per ADR-001: only JSON DSL enters Freqtrade; no Python generation.
Per §13: all indicators, operators, rule types must be whitelisted.
"""
import enum
from typing import Annotated, Literal, Optional, Any, Union

from pydantic import BaseModel, Field, model_validator


# ── Whitelists ──────────────────────────────────────────────────────

class DSLIndicator(str, enum.Enum):
    RSI = "rsi"
    EMA = "ema"
    SMA = "sma"
    MACD = "macd"
    MACD_SIGNAL = "macd_signal"
    BB_UPPER = "bb_upper"
    BB_LOWER = "bb_lower"
    ATR = "atr"
    VOLUME = "volume"
    VOLUME_SMA = "volume_sma"
    CLOSE = "close"
    OPEN = "open"
    HIGH = "high"
    LOW = "low"


class DSLOperator(str, enum.Enum):
    GT = ">"
    GTE = ">="
    LT = "<"
    LTE = "<="
    EQ = "=="
    NEQ = "!="
    CROSSES_ABOVE = "crosses_above"
    CROSSES_BELOW = "crosses_below"
    BETWEEN = "between"
    NOT_BETWEEN = "not_between"


class DSLRuleType(str, enum.Enum):
    INDICATOR_THRESHOLD = "indicator_threshold"
    INDICATOR_CROSS = "indicator_cross"
    SIGNAL_CONFIRMATION = "signal_confirmation"
    MANIPULATION_SCORE_FILTER = "manipulation_score_filter"
    VOLUME_FILTER = "volume_filter"
    VOLATILITY_FILTER = "volatility_filter"
    COOLDOWN_FILTER = "cooldown_filter"
    PORTFOLIO_EXPOSURE_FILTER = "portfolio_exposure_filter"


class DSLLogic(str, enum.Enum):
    AND = "AND"
    OR = "OR"


SUPPORTED_SCHEMA_VERSIONS = {"2.5", "3.0"}

ALLOWED_TIMEFRAMES = {
    "1m", "3m", "5m", "15m", "30m",
    "1h", "2h", "4h", "6h", "8h", "12h",
    "1d", "3d", "1w", "1M",
}

SCALAR_OPERATORS = {
    DSLOperator.GT, DSLOperator.GTE, DSLOperator.LT,
    DSLOperator.LTE, DSLOperator.EQ, DSLOperator.NEQ,
}
RANGE_OPERATORS = {DSLOperator.BETWEEN, DSLOperator.NOT_BETWEEN}
CROSS_OPERATORS = {DSLOperator.CROSSES_ABOVE, DSLOperator.CROSSES_BELOW}

ALLOWED_MISSING_DATA_POLICIES = {"reject", "degrade_to_paper_only"}

INDICATORS_REQUIRING_PERIOD = {
    DSLIndicator.RSI, DSLIndicator.EMA, DSLIndicator.SMA,
    DSLIndicator.MACD, DSLIndicator.MACD_SIGNAL,
    DSLIndicator.BB_UPPER, DSLIndicator.BB_LOWER,
    DSLIndicator.ATR, DSLIndicator.VOLUME_SMA,
}


# ── Rule models ─────────────────────────────────────────────────────

class IndicatorThresholdRule(BaseModel):
    type: Literal["indicator_threshold"]
    indicator: DSLIndicator
    params: dict[str, Any] = Field(default_factory=dict)
    operator: DSLOperator
    value: Optional[float | int] = None
    min_value: Optional[float | int] = None
    max_value: Optional[float | int] = None

    @model_validator(mode="after")
    def _validate_value_shape(self):
        if self.operator in CROSS_OPERATORS:
            raise ValueError("indicator_threshold does not support cross operators; use indicator_cross")
        if self.operator in RANGE_OPERATORS:
            if self.min_value is None or self.max_value is None:
                raise ValueError("between/not_between requires min_value and max_value")
            if self.min_value > self.max_value:
                raise ValueError("min_value must be <= max_value")
        else:
            if self.value is None:
                raise ValueError("scalar operator requires value")
        return self


class IndicatorCrossRule(BaseModel):
    type: Literal["indicator_cross"]
    indicator: DSLIndicator
    params: dict[str, Any] = Field(default_factory=dict)
    cross_indicator: DSLIndicator
    cross_params: dict[str, Any] = Field(default_factory=dict)
    direction: Literal["crosses_above", "crosses_below"]


class SignalConfirmationRule(BaseModel):
    type: Literal["signal_confirmation"]
    min_confidence: float = Field(ge=0.0, le=1.0)
    required_direction: Optional[str] = None


class ManipulationScoreFilterRule(BaseModel):
    type: Literal["manipulation_score_filter"]
    max_score: float = Field(ge=0.0, le=1.0)
    missing_data_policy: str = Field(default="reject")


class VolumeFilterRule(BaseModel):
    type: Literal["volume_filter"]
    indicator: Literal["volume", "volume_sma"] = "volume"
    params: dict[str, Any] = Field(default_factory=dict)
    operator: DSLOperator
    value: float | int


class VolatilityFilterRule(BaseModel):
    type: Literal["volatility_filter"]
    indicator: Literal["atr"] = "atr"
    params: dict[str, Any] = Field(default_factory=dict)
    operator: DSLOperator
    value: float | int


class CooldownFilterRule(BaseModel):
    type: Literal["cooldown_filter"]
    candles: int = Field(ge=1)


class PortfolioExposureFilterRule(BaseModel):
    type: Literal["portfolio_exposure_filter"]
    max_exposure_pct: float = Field(gt=0.0, le=1.0)


DSLRule = Annotated[
    Union[
        IndicatorThresholdRule,
        IndicatorCrossRule,
        SignalConfirmationRule,
        ManipulationScoreFilterRule,
        VolumeFilterRule,
        VolatilityFilterRule,
        CooldownFilterRule,
        PortfolioExposureFilterRule,
    ],
    Field(discriminator="type"),
]


# ── Top-level structures ────────────────────────────────────────────

class RuleGroup(BaseModel):
    logic: DSLLogic = DSLLogic.AND
    rules: list[DSLRule] = Field(min_length=1)


class PositionSizing(BaseModel):
    type: Literal["fixed_pct"] = "fixed_pct"
    position_pct: float = Field(gt=0.0, le=1.0)


class RiskConfig(BaseModel):
    stoploss: float = Field(lt=0.0)
    trailing_stop: Optional[bool] = None
    trailing_stop_positive: Optional[float] = None
    trailing_stop_positive_offset: Optional[float] = None
    max_open_trades: int = Field(ge=1)
    cooldown: Optional[int] = None


class DSLMetadata(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    tags: list[str] = Field(default_factory=list)
    author: Optional[str] = None


class RulePackage(BaseModel):
    schema_version: str
    strategy_version_id: Optional[str] = None
    dsl_hash: Optional[str] = None
    timeframe: str
    symbols: list[str] = Field(min_length=1)
    entry: RuleGroup
    exit: RuleGroup
    filters: list[DSLRule] = Field(default_factory=list)
    position_sizing: PositionSizing
    risk: RiskConfig
    metadata: DSLMetadata = Field(default_factory=DSLMetadata)

    @model_validator(mode="after")
    def _validate_schema_version(self):
        if self.schema_version not in SUPPORTED_SCHEMA_VERSIONS:
            raise ValueError(f"schema_version '{self.schema_version}' not supported; allowed: {SUPPORTED_SCHEMA_VERSIONS}")
        return self

    @model_validator(mode="after")
    def _validate_timeframe(self):
        if self.timeframe not in ALLOWED_TIMEFRAMES:
            raise ValueError(f"timeframe '{self.timeframe}' not allowed; allowed: {sorted(ALLOWED_TIMEFRAMES)}")
        return self

# ── DSL v3.0 Models ─────────────────────────────────────────────────

class StrategyMeta(BaseModel):
    id: str
    name: str
    symbol: str
    timeframe: str
    mode: Literal["auto", "semi_auto", "manual"] = "auto"


class RuntimeMode(BaseModel):
    execution_architecture: Literal["dual_track", "single_track"] = "dual_track"
    fast_track_required: bool = True
    slow_track_ai_cache_required: bool = False
    max_fast_track_latency_ms: int = Field(default=200, ge=50, le=5000)


class DataRequirements(BaseModel):
    kline: list[str] = Field(default_factory=lambda: ["5m"])
    orderbook: bool = False
    indicators: list[str] = Field(default_factory=lambda: ["rsi", "atr"])
    structure: list[str] = Field(default_factory=list)
    ai_cache: list[str] = Field(default_factory=list)


class StopPolicy(BaseModel):
    mode: Literal["structure_invalidated", "fixed_pct", "trailing"] = "structure_invalidated"
    priority: list[str] = Field(default_factory=lambda: [
        "sweep_low", "order_block_low", "fvg_low", "fallback_fixed_pct"
    ])
    atr_buffer_coef: float = Field(default=0.3, ge=0.0, le=2.0)
    fallback_stop_pct: float = Field(default=0.02, gt=0.0, le=0.1)
    max_stop_distance_pct: float = Field(default=0.03, gt=0.0, le=0.1)
    min_reward_risk: float = Field(default=1.5, ge=1.0)
    stop_liquidity_safety_check: bool = True


class PositionPolicy(BaseModel):
    risk_per_trade: float = Field(default=0.01, gt=0.0, le=0.05)
    max_position_pct: float = Field(default=0.1, gt=0.0, le=0.5)
    size_adjustment_by_ai_risk: bool = True
    size_adjustment_by_market_regime: bool = True


class AddPositionPolicy(BaseModel):
    allow_dca: bool = False
    allow_structure_add: bool = True
    max_add_count: int = Field(default=2, ge=0, le=5)
    require_stop_above_breakeven: bool = True
    max_total_risk_after_add: float = Field(default=0.01, gt=0.0, le=0.05)
    min_reward_risk_after_add: float = Field(default=1.5, ge=1.0)
    min_liquidation_distance_pct: float = Field(default=0.08, ge=0.01)


class AccountRiskPolicy(BaseModel):
    max_daily_loss: float = Field(default=0.03, gt=0.0, le=0.1)
    max_weekly_loss: float = Field(default=0.08, gt=0.0, le=0.2)
    max_consecutive_losses: int = Field(default=4, ge=1, le=20)
    kill_switch_enabled: bool = True


class DisconnectProtection(BaseModel):
    enabled: bool = True
    max_snapshot_miss_ticks: int = Field(default=3, ge=1, le=20)
    hard_disconnect_timeout_ms: int = Field(default=3000, ge=1000, le=60000)
    fallback_stop_mode: Literal["static_percentage", "last_valid"] = "static_percentage"
    fallback_stop_pct: float = Field(default=0.02, gt=0.0, le=0.1)
    prefer_last_valid_stop: bool = True
    emergency_action: Literal["market_close", "limit_close"] = "market_close"
    block_new_entries: bool = True
    place_exchange_side_stop: bool = True


class ExecutionPolicy(BaseModel):
    engine: Literal["freqtrade", "ccxt_direct"] = "freqtrade"
    order_type: Literal["limit", "market"] = "limit"
    slippage_limit: float = Field(default=0.002, ge=0.0, le=0.01)
    manual_confirm_required: bool = False


class DegradationPolicy(BaseModel):
    ai_cache_soft_expired: Literal["reduce_size", "block_new_entries", "ignore"] = "reduce_size"
    ai_cache_hard_expired: Literal["reduce_size", "block_new_entries", "ignore"] = "block_new_entries"
    redis_unavailable: Literal["disconnect_protection", "pause_strategy"] = "disconnect_protection"
    structure_engine_error: Literal["manual_confirm_only", "block_new_entries"] = "manual_confirm_only"
    freqtrade_heartbeat_lost: Literal["pause_strategy", "emergency_close"] = "pause_strategy"


class LiquidityExecutionSafety(BaseModel):
    enabled: bool = True
    spread_buffer_coef: float = Field(default=1.0, ge=0.0)
    slippage_buffer_coef: float = Field(default=1.0, ge=0.0)
    liquidity_void_multiplier: float = Field(default=1.5, ge=1.0)
    max_allowed_spread_pct: float = Field(default=0.003, gt=0.0)
    min_depth_score: float = Field(default=0.4, ge=0.0, le=1.0)
    action_on_wide_spread: Literal["reject_trade", "reduce_size", "manual_confirm_required"] = "reject_trade"
    action_on_thin_depth: Literal["reject_trade", "reduce_size", "manual_confirm_required"] = "manual_confirm_required"


class TimeframeIntegrityPolicy(BaseModel):
    enabled: bool = True
    invalidate_only_on_same_or_higher_timeframe_close: bool = True
    low_timeframe_violation_action: Literal["mark_temporary_violation", "ignore"] = "mark_temporary_violation"
    allow_low_timeframe_to_update_filled_ratio: bool = True


class RulePackageV3(BaseModel):
    schema_version: Literal["3.0"]
    strategy: StrategyMeta
    runtime_mode: RuntimeMode = Field(default_factory=RuntimeMode)
    data_requirements: DataRequirements = Field(default_factory=DataRequirements)
    entry_logic: RuleGroup
    exit_logic: RuleGroup
    filters: list[DSLRule] = Field(default_factory=list)
    stop_policy: StopPolicy = Field(default_factory=StopPolicy)
    position_policy: PositionPolicy = Field(default_factory=PositionPolicy)
    add_position_policy: AddPositionPolicy = Field(default_factory=AddPositionPolicy)
    account_risk_policy: AccountRiskPolicy = Field(default_factory=AccountRiskPolicy)
    disconnect_protection: DisconnectProtection = Field(default_factory=DisconnectProtection)
    execution_policy: ExecutionPolicy = Field(default_factory=ExecutionPolicy)
    degradation_policy: DegradationPolicy = Field(default_factory=DegradationPolicy)
    liquidity_execution_safety: LiquidityExecutionSafety = Field(default_factory=LiquidityExecutionSafety)
    timeframe_integrity_policy: TimeframeIntegrityPolicy = Field(default_factory=TimeframeIntegrityPolicy)
    metadata: DSLMetadata = Field(default_factory=DSLMetadata)


# ── DSL v3.0 MTF Guard Models ──────────────────────────────────────


class ShadowWindowConfig(BaseModel):
    """Configuration for the shadow observation window."""
    mode: str = "until_slow_candle_close"
    max_fast_candles: int = 12
    allow_low_tf_touch: bool = True
    allow_low_tf_update_filled_ratio: bool = True


class ViolationPolicy(BaseModel):
    """Policy mapping guard states to entry actions."""
    temporary_violation: str = "block_entry"
    reclaim_pending: str = "require_confirmation"
    confirmed_reclaim: str = "allow"
    confirmed_break: str = "invalidate"


class MTFGuardRule(BaseModel):
    """MTF Temporal Guard rule — cross-timeframe structure defense node."""
    type: Literal["mtf_guard"] = "mtf_guard"
    guard_id: str
    name: str
    fast_timeframe: str
    slow_timeframe: str
    source_node: str
    target_node: str
    structure_type: str
    shadow_window: ShadowWindowConfig = Field(default_factory=ShadowWindowConfig)
    violation_policy: ViolationPolicy = Field(default_factory=ViolationPolicy)
    reason_codes: dict[str, str] = Field(default_factory=dict)
