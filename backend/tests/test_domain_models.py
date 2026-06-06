"""Domain model instantiation and table registration tests."""
import uuid
from datetime import datetime, timezone

from app.database.base import Base
from app.domain.signal import SignalIdentity, Signal, SignalPayload, SignalEvidence, SignalLifecycleEvent, SignalSnapshot
from app.domain.provider import ProviderTrace
from app.domain.strategy import StrategyV2, StrategyVersion, StrategyRuleDSLVersion
from app.domain.risk import RiskPolicy, RiskPolicyVersion, CapitalPool, StrategyRiskPolicyBinding
from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.command import CommandBusCommand
from app.domain.ledger import ExecutionLedgerEvent
from app.domain.order import ExecutionOrder, ExecutionTrade, ExecutionPosition, OrderFill
from app.domain.trade_intent import TradeIntent, TradeIntentSignalSnapshot, RiskDecision
from app.domain.outbox import OutboxEvent


EXPECTED_V2_TABLES = {
    "signal_identity", "signals", "signal_payloads", "signal_evidence",
    "signal_lifecycle_events", "signal_snapshots",
    "provider_traces",
    "strategies_v2", "strategy_versions", "strategy_rule_dsl_versions",
    "risk_policies", "risk_policy_versions", "capital_pools", "strategy_risk_policy_bindings",
    "strategy_runs", "freqtrade_runs",
    "command_bus_commands",
    "execution_ledger_events",
    "execution_orders", "execution_trades", "execution_positions", "order_fills",
    "trade_intents", "trade_intent_signal_snapshots", "risk_decisions",
    "outbox_events",
}


def test_all_v2_tables_registered():
    registered = set(Base.metadata.tables.keys())
    missing = EXPECTED_V2_TABLES - registered
    assert not missing, f"Missing tables: {missing}"


def test_signal_identity_instantiation():
    sid = uuid.uuid4()
    obj = SignalIdentity(id=sid)
    assert obj.id == sid


def test_signal_instantiation():
    now = datetime.now(timezone.utc)
    obj = Signal(id=uuid.uuid4(), created_at=now, source_type="test",
                 symbol="BTC/USDT", market="crypto", direction="long",
                 status="pending", permission={}, valid_from=now, updated_at=now)
    assert obj.symbol == "BTC/USDT"
    assert obj.direction == "long"


def test_command_bus_command_instantiation():
    obj = CommandBusCommand(
        command_type="start_backtest", aggregate_type="strategy_run",
        payload={"test": True}, idempotency_key="test-key-1",
        requested_by="test_user",
    )
    assert obj.command_type == "start_backtest"
    assert obj.idempotency_key == "test-key-1"


def test_execution_ledger_event_instantiation():
    now = datetime.now(timezone.utc)
    obj = ExecutionLedgerEvent(
        id=uuid.uuid4(), event_time=now,
        event_type="PULSEDESK_COMMAND_STARTED", source_system="pulsedesk",
        event_hash="abc123", normalized_payload={"test": True},
    )
    assert obj.event_type == "PULSEDESK_COMMAND_STARTED"
    assert obj.source_system == "pulsedesk"


def test_strategy_version_instantiation():
    obj = StrategyVersion(
        strategy_id=uuid.uuid4(), version_no=1, status="draft",
        dsl_version="2.5", rule_dsl={"entry": {}}, dsl_hash="sha256:abc",
        created_by="test",
    )
    assert obj.version_no == 1


def test_capital_pool_instantiation():
    obj = CapitalPool(
        name="Test Pool", pool_type="paper", currency="USDT",
        total_budget=10000, max_position_pct_per_trade=0.02,
        max_total_exposure_pct=0.1, max_daily_loss_pct=0.05,
        max_drawdown_pct=0.15,
    )
    assert obj.name == "Test Pool"
    assert obj.pool_type == "paper"
