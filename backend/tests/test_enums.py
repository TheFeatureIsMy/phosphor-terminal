"""Enum completeness tests."""
from app.domain.enums import (
    SignalDirection, SignalStatus, SignalRiskLevel,
    StrategyStatus, StrategyVersionStatus,
    CommandType, CommandStatus,
    StrategyRunMode, StrategyRunStatus,
    RiskDecisionType, RiskPolicyType, CapitalPoolType,
    TradeIntentType, TradeIntentSide, TradeIntentStatus,
    ProviderTraceObjectType, OutboxEventStatus,
)


def test_signal_direction_values():
    assert set(e.value for e in SignalDirection) == {"long", "short", "hold", "risk", "block", "neutral"}


def test_signal_status_values():
    assert "pending" in [e.value for e in SignalStatus]
    assert "active" in [e.value for e in SignalStatus]
    assert len(SignalStatus) == 7


def test_command_type_values():
    assert len(CommandType) == 8
    assert "deploy_rules" in [e.value for e in CommandType]
    assert "emergency_stop" in [e.value for e in CommandType]


def test_command_status_values():
    assert len(CommandStatus) == 7
    assert "pending" in [e.value for e in CommandStatus]
    assert "retry_waiting" in [e.value for e in CommandStatus]


def test_strategy_run_status_values():
    assert len(StrategyRunStatus) == 9
    assert "reconciliating" in [e.value for e in StrategyRunStatus]
    assert "manual_review_required" in [e.value for e in StrategyRunStatus]


def test_risk_decision_type_values():
    assert len(RiskDecisionType) == 7
    vals = [e.value for e in RiskDecisionType]
    assert "ALLOW" in vals
    assert "DEPLOYMENT_REJECTED" in vals


def test_all_enums_are_str_enum():
    """All enums must be str enum for JSON serialization."""
    for enum_cls in [
        SignalDirection, SignalStatus, CommandType, CommandStatus,
        StrategyRunMode, StrategyRunStatus, RiskDecisionType,
        StrategyVersionStatus, TradeIntentStatus,
    ]:
        for member in enum_cls:
            assert isinstance(member.value, str), f"{enum_cls.__name__}.{member.name} is not str"
