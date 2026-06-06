import pytest
from app.services.position_calculator import calculate_position_size

def test_basic_risk_sizing():
    r = calculate_position_size(
        account_equity=100000, risk_per_trade=0.01,
        entry_price=60000, stop_price=59400,
        max_position_pct=1.0,
    )
    assert r.method == "risk_based"
    assert r.risk_amount == pytest.approx(1000, rel=0.1)
    assert r.stop_distance == pytest.approx(600, rel=0.01)
    assert r.position_size > 0

def test_clamped_to_max_pct():
    r = calculate_position_size(
        account_equity=100000, risk_per_trade=0.01,
        entry_price=60000, stop_price=59990,
        max_position_pct=0.1,
    )
    assert r.position_pct <= 0.1

def test_ai_multiplier_halves():
    r1 = calculate_position_size(
        account_equity=100000, risk_per_trade=0.01,
        entry_price=60000, stop_price=59400,
        ai_size_multiplier=1.0, max_position_pct=1.0,
    )
    r2 = calculate_position_size(
        account_equity=100000, risk_per_trade=0.01,
        entry_price=60000, stop_price=59400,
        ai_size_multiplier=0.5, max_position_pct=1.0,
    )
    assert r2.position_size == pytest.approx(r1.position_size * 0.5, rel=0.01)

def test_zero_distance_fallback():
    r = calculate_position_size(
        account_equity=100000, risk_per_trade=0.01,
        entry_price=60000, stop_price=60000,
    )
    assert r.method == "fixed_pct_fallback"
    assert r.position_size > 0

def test_leverage_scaling():
    r1 = calculate_position_size(
        account_equity=100000, risk_per_trade=0.01,
        entry_price=60000, stop_price=59400,
        leverage=1.0, max_position_pct=5.0,
    )
    r2 = calculate_position_size(
        account_equity=100000, risk_per_trade=0.01,
        entry_price=60000, stop_price=59400,
        leverage=2.0, max_position_pct=5.0,
    )
    assert r2.position_size == pytest.approx(r1.position_size * 2, rel=0.01)
