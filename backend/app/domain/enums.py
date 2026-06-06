"""PulseDesk v2.5 受控枚举 — 所有状态字段必须使用这些枚举。"""
import enum


class SignalDirection(str, enum.Enum):
    LONG = "long"
    SHORT = "short"
    HOLD = "hold"
    RISK = "risk"
    BLOCK = "block"
    NEUTRAL = "neutral"


class SignalStatus(str, enum.Enum):
    PENDING = "pending"
    ACTIVE = "active"
    EXPIRED = "expired"
    REJECTED = "rejected"
    EXECUTED = "executed"
    ARCHIVED = "archived"
    DEGRADED = "degraded"


class SignalRiskLevel(str, enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    EXTREME = "extreme"


class StrategyStatus(str, enum.Enum):
    DRAFT = "draft"
    ACTIVE = "active"
    PAUSED = "paused"
    ARCHIVED = "archived"
    REJECTED = "rejected"


class StrategyVersionStatus(str, enum.Enum):
    DRAFT = "draft"
    VALIDATED = "validated"
    BACKTESTED = "backtested"
    PAPER_RUNNING = "paper_running"
    PAPER_PASSED = "paper_passed"
    LIVE_PENDING = "live_pending"
    LIVE_SMALL = "live_small"
    PAUSED = "paused"
    ARCHIVED = "archived"
    REJECTED = "rejected"


class CommandType(str, enum.Enum):
    DEPLOY_RULES = "deploy_rules"
    START_BACKTEST = "start_backtest"
    START_DRYRUN = "start_dryrun"
    STOP_DRYRUN = "stop_dryrun"
    PAUSE_STRATEGY = "pause_strategy"
    REQUEST_LIVE_SMALL = "request_live_small"
    EMERGENCY_STOP = "emergency_stop"
    START_RECONCILIATION = "start_reconciliation"


class CommandStatus(str, enum.Enum):
    PENDING = "pending"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELLED = "cancelled"
    TIMEOUT = "timeout"
    RETRY_WAITING = "retry_waiting"


class StrategyRunMode(str, enum.Enum):
    BACKTEST = "backtest"
    DRY_RUN = "dry_run"
    SHADOW = "shadow"
    LIVE_SMALL = "live_small"


class StrategyRunStatus(str, enum.Enum):
    CREATED = "created"
    STARTING = "starting"
    RUNNING = "running"
    STOPPING = "stopping"
    STOPPED = "stopped"
    FAILED = "failed"
    DEGRADED = "degraded"
    RECONCILIATING = "reconciliating"
    MANUAL_REVIEW_REQUIRED = "manual_review_required"


class RiskDecisionType(str, enum.Enum):
    ALLOW = "ALLOW"
    REDUCE_SIZE = "REDUCE_SIZE"
    REJECT = "REJECT"
    PAPER_ONLY = "PAPER_ONLY"
    HUMAN_CONFIRM = "HUMAN_CONFIRM"
    DEPLOYMENT_APPROVED = "DEPLOYMENT_APPROVED"
    DEPLOYMENT_REJECTED = "DEPLOYMENT_REJECTED"


class RiskPolicyType(str, enum.Enum):
    CONSERVATIVE = "conservative"
    BALANCED = "balanced"
    HIGH_RISK_HUNT = "high_risk_hunt"
    LIVE_SMALL = "live_small"
    CUSTOM = "custom"


class RiskPolicyStatus(str, enum.Enum):
    DRAFT = "draft"
    ACTIVE = "active"
    ARCHIVED = "archived"


class CapitalPoolType(str, enum.Enum):
    PAPER = "paper"
    MAIN = "main"
    HIGH_RISK_HUNT = "high_risk_hunt"
    LIVE_SMALL = "live_small"


class TradeIntentType(str, enum.Enum):
    PLANNED = "planned"
    FREQTRADE_EXECUTION = "freqtrade_execution"


class TradeIntentSide(str, enum.Enum):
    BUY = "buy"
    SELL = "sell"
    CLOSE = "close"
    REDUCE = "reduce"


class TradeIntentStatus(str, enum.Enum):
    CREATED = "created"
    RISK_EVALUATED = "risk_evaluated"
    REJECTED = "rejected"
    APPROVED = "approved"
    SENT = "sent"
    CANCELLED = "cancelled"
    EXECUTED = "executed"


class ProviderTraceObjectType(str, enum.Enum):
    SIGNAL = "signal"
    RESEARCH_REPORT = "research_report"
    STRATEGY_DRAFT = "strategy_draft"
    STRATEGY_VERSION = "strategy_version"
    GROWTH_REPORT = "growth_report"


class OutboxEventStatus(str, enum.Enum):
    PENDING = "pending"
    PROCESSED = "processed"
    FAILED = "failed"


class LedgerEventType(str, enum.Enum):
    FREQTRADE_RUN_STARTED = "FREQTRADE_RUN_STARTED"
    FREQTRADE_RUN_HEARTBEAT = "FREQTRADE_RUN_HEARTBEAT"
    FREQTRADE_ORDER_OPENED = "FREQTRADE_ORDER_OPENED"
    FREQTRADE_ORDER_FILLED = "FREQTRADE_ORDER_FILLED"
    FREQTRADE_ORDER_CANCELLED = "FREQTRADE_ORDER_CANCELLED"
    FREQTRADE_TRADE_OPENED = "FREQTRADE_TRADE_OPENED"
    FREQTRADE_TRADE_CLOSED = "FREQTRADE_TRADE_CLOSED"
    FREQTRADE_STOPLOSS_TRIGGERED = "FREQTRADE_STOPLOSS_TRIGGERED"
    FREQTRADE_RUN_DEGRADED = "FREQTRADE_RUN_DEGRADED"
    FREQTRADE_RUN_STOPPED = "FREQTRADE_RUN_STOPPED"
    FREQTRADE_BACKTEST_STARTED = "FREQTRADE_BACKTEST_STARTED"
    FREQTRADE_BACKTEST_COMPLETED = "FREQTRADE_BACKTEST_COMPLETED"
    FREQTRADE_BACKTEST_FAILED = "FREQTRADE_BACKTEST_FAILED"

    PULSEDESK_COMMAND_STARTED = "PULSEDESK_COMMAND_STARTED"
    PULSEDESK_COMMAND_SUCCEEDED = "PULSEDESK_COMMAND_SUCCEEDED"
    PULSEDESK_COMMAND_FAILED = "PULSEDESK_COMMAND_FAILED"
    PULSEDESK_RISK_DECISION_CREATED = "PULSEDESK_RISK_DECISION_CREATED"
    PULSEDESK_SAFE_HOLD_ENTERED = "PULSEDESK_SAFE_HOLD_ENTERED"
    PULSEDESK_EMERGENCY_STOP_REQUESTED = "PULSEDESK_EMERGENCY_STOP_REQUESTED"
    PULSEDESK_RECONCILIATION_STARTED = "PULSEDESK_RECONCILIATION_STARTED"
    PULSEDESK_RECONCILIATION_COMPLETED = "PULSEDESK_RECONCILIATION_COMPLETED"
    PULSEDESK_MANUAL_REVIEW_REQUIRED = "PULSEDESK_MANUAL_REVIEW_REQUIRED"


class LedgerSourceSystem(str, enum.Enum):
    FREQTRADE = "freqtrade"
    PULSEDESK = "pulsedesk"


class InferenceJobStatus(str, enum.Enum):
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class ModelRuntimeStateEnum(str, enum.Enum):
    IDLE = "idle"
    LOADED = "loaded"
    RUNNING = "running"
    OOM = "oom"


class ReconciliationStatus(str, enum.Enum):
    STARTED = "started"
    COMPLETED = "completed"
    FAILED = "failed"


class ConnectionState(str, enum.Enum):
    HEALTHY = "healthy"
    CONNECTION_LOST = "connection_lost"
    PULSE_DEGRADED = "pulse_degraded"
    FREQTRADE_NATIVE_GUARD_ONLY = "freqtrade_native_guard_only"
    RECONCILIATING = "reconciliating"
    FAILED = "failed"


class ArchivalJobStatus(str, enum.Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
