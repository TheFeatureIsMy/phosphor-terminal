import pytest
from app.domain.dsl import AddPositionPolicy
from app.services.add_position_validator import (
    AddPositionRequest, validate_add_position,
)
from app.services.blended_entry import calculate_blended_entry, calculate_total_risk

def _default_policy(**overrides):
    defaults = dict(
        allow_dca=False, allow_structure_add=True,
        max_add_count=2, require_stop_above_breakeven=True,
        max_total_risk_after_add=0.01,
        min_reward_risk_after_add=1.5,
        min_liquidation_distance_pct=0.08,
    )
    defaults.update(overrides)
    return AddPositionPolicy(**defaults)

def _default_request(**overrides):
    defaults = dict(
        current_size=0.1, current_avg_entry=60000,
        current_stop=60500, current_add_count=0,
        add_entry_price=61000, add_size=0.05,
        new_structural_stop=59500, account_equity=100000,
        policy=_default_policy(),
        structure_valid=True, structure_signal_confirmed=True,
        direction="long",
        take_profit_price=64000, liquidation_price=55000,
    )
    defaults.update(overrides)
    return AddPositionRequest(**defaults)

def test_valid_add_allowed():
    result = validate_add_position(_default_request())
    assert result.allowed is True
    assert len(result.reject_reasons) == 0

def test_dca_rejected():
    policy = _default_policy(allow_structure_add=False, allow_dca=False)
    result = validate_add_position(_default_request(policy=policy))
    assert result.allowed is False
    assert "position_adding_not_allowed" in result.reject_reasons

def test_structure_invalidated():
    result = validate_add_position(_default_request(structure_valid=False))
    assert result.allowed is False
    assert "structure_invalidated" in result.reject_reasons

def test_breakeven_not_met():
    result = validate_add_position(_default_request(current_stop=59000))
    assert result.allowed is False
    assert "stop_below_breakeven" in result.reject_reasons

def test_risk_budget_exceeded():
    policy = _default_policy(max_total_risk_after_add=0.001)
    result = validate_add_position(_default_request(policy=policy))
    assert result.allowed is False
    assert "risk_budget_exceeded" in result.reject_reasons

def test_max_add_count():
    result = validate_add_position(_default_request(current_add_count=2))
    assert result.allowed is False
    assert "max_add_count_reached" in result.reject_reasons

def test_blended_entry_math():
    blended = calculate_blended_entry(0.1, 60000, 0.05, 61000)
    expected = (0.1 * 60000 + 0.05 * 61000) / 0.15
    assert blended == pytest.approx(expected)

def test_liquidation_distance_unsafe():
    result = validate_add_position(_default_request(liquidation_price=60500))
    assert result.allowed is False
    assert "liquidation_distance_unsafe" in result.reject_reasons
