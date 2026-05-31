import pytest
from app.services.slippage import calculate_slippage


def test_execution_within_tolerance():
    result = calculate_slippage(
        signal_price=50000.0,
        filled_price=50005.0,
    )
    assert result["diagnosis"] == "execution_within_tolerance"
    assert abs(result["slippage_pct"]) < 0.05


def test_positive_slippage_above_tolerance():
    result = calculate_slippage(
        signal_price=100.0,
        filled_price=100.1,
    )
    assert result["diagnosis"] == "negative_buy_slippage_or_positive_sell_improvement"
    assert result["slippage_pct"] == 0.1


def test_negative_slippage_improvement():
    result = calculate_slippage(
        signal_price=100.0,
        filled_price=99.8,
    )
    assert result["diagnosis"] == "positive_buy_improvement_or_negative_sell_slippage"
    assert result["slippage_pct"] == -0.2


def test_execution_costs_dominated():
    result = calculate_slippage(
        signal_price=100.0,
        filled_price=100.5,
        spread_cost=50.0,
        market_impact=30.0,
        latency_cost=20.0,
    )
    assert result["diagnosis"] == "execution_costs_dominated"


def test_execution_costs_not_dominated():
    result = calculate_slippage(
        signal_price=100.0,
        filled_price=100.5,
        spread_cost=0.05,
        market_impact=0.03,
        latency_cost=0.02,
    )
    assert result["diagnosis"] == "negative_buy_slippage_or_positive_sell_improvement"


def test_zero_signal_price_returns_zero_pct():
    result = calculate_slippage(
        signal_price=0.0,
        filled_price=100.0,
    )
    assert result["slippage_pct"] == 0
    assert result["execution_slippage"] == 100.0


def test_precision_rounding():
    result = calculate_slippage(
        signal_price=1.23456789,
        filled_price=1.23457789,
    )
    assert result["execution_slippage"] == 1e-05
    assert result["slippage_pct"] == 0.00081


def test_negative_spread_and_impact_handled():
    result = calculate_slippage(
        signal_price=200.0,
        filled_price=200.5,
        spread_cost=0,
        market_impact=0,
        latency_cost=0,
    )
    assert result["diagnosis"] == "negative_buy_slippage_or_positive_sell_improvement"
    assert result["slippage_pct"] == 0.25
