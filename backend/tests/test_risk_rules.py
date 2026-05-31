import pytest
from app.services.risk_rules import evaluate_risk_rules


def test_stop_loss_triggered_at_exact_threshold():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "symbol": "BTC/USDT",
        "position_pnl_pct": -5.0,
    })
    assert len(events) == 1
    assert events[0]["event_type"] == "stop_loss"
    assert events[0]["severity"] == "medium"


def test_stop_loss_high_severity_at_eight_percent():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "symbol": "BTC/USDT",
        "position_pnl_pct": -8.0,
    })
    assert len(events) == 1
    assert events[0]["severity"] == "high"


def test_stop_loss_not_triggered_below_threshold():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "symbol": "BTC/USDT",
        "position_pnl_pct": -4.9,
    })
    assert len(events) == 0


def test_stop_loss_not_triggered_on_gain():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "symbol": "BTC/USDT",
        "position_pnl_pct": 5.0,
    })
    assert len(events) == 0


def test_stop_loss_not_triggered_when_missing():
    events = evaluate_risk_rules({"strategy_id": 1})
    assert len(events) == 0


def test_take_profit_triggered_at_exact_threshold():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "symbol": "ETH/USDT",
        "take_profit_pct": 8.0,
    })
    assert len(events) == 1
    assert events[0]["event_type"] == "take_profit"
    assert events[0]["severity"] == "low"


def test_take_profit_not_triggered_below_threshold():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "symbol": "ETH/USDT",
        "take_profit_pct": 7.9,
    })
    assert len(events) == 0


def test_max_drawdown_triggered_at_custom_limit():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "drawdown_pct": 15.0,
        "max_drawdown_pct": 10.0,
    })
    assert len(events) == 1
    assert events[0]["event_type"] == "max_drawdown"
    assert events[0]["severity"] == "critical"


def test_max_drawdown_not_triggered_below_limit():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "drawdown_pct": 9.0,
        "max_drawdown_pct": 10.0,
    })
    assert len(events) == 0


def test_max_drawdown_uses_default_ten():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "drawdown_pct": 10.0,
    })
    assert len(events) == 1
    assert events[0]["event_type"] == "max_drawdown"


def test_correlation_warning_triggered_at_ninety():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "correlation_pairs": [
            {"symbol_a": "BTC/USDT", "symbol_b": "ETH/USDT", "correlation": 0.9},
        ],
    })
    assert len(events) == 1
    assert events[0]["event_type"] == "correlation_warning"
    assert events[0]["severity"] == "medium"


def test_correlation_warning_not_triggered_below_ninety():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "correlation_pairs": [
            {"symbol_a": "BTC/USDT", "symbol_b": "ETH/USDT", "correlation": 0.89},
        ],
    })
    assert len(events) == 0


def test_multiple_correlation_pairs():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "correlation_pairs": [
            {"symbol_a": "A", "symbol_b": "B", "correlation": 0.95},
            {"symbol_a": "A", "symbol_b": "C", "correlation": 0.5},
            {"symbol_a": "A", "symbol_b": "D", "correlation": 0.91},
        ],
    })
    assert len(events) == 2
    assert all(e["event_type"] == "correlation_warning" for e in events)


def test_api_error_creates_event():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "api_error": "Binance API timeout after 5s",
    })
    assert len(events) == 1
    assert events[0]["event_type"] == "api_error"
    assert events[0]["severity"] == "high"


def test_api_error_empty_string_not_triggered():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "api_error": "",
    })
    assert len(events) == 0


def test_multiple_rules_can_fire_together():
    events = evaluate_risk_rules({
        "strategy_id": 1,
        "symbol": "BTC/USDT",
        "position_pnl_pct": -10.0,
        "take_profit_pct": 12.0,
        "drawdown_pct": 15.0,
        "max_drawdown_pct": 10.0,
        "correlation_pairs": [
            {"symbol_a": "BTC", "symbol_b": "ETH", "correlation": 0.95},
        ],
        "api_error": "exchange_unreachable",
    })
    assert len(events) == 5
    types = [e["event_type"] for e in events]
    assert "stop_loss" in types
    assert "take_profit" in types
    assert "max_drawdown" in types
    assert "correlation_warning" in types
    assert "api_error" in types


def test_default_market_is_crypto():
    events = evaluate_risk_rules({
        "position_pnl_pct": -6.0,
    })
    assert events[0]["market"] == "crypto"


def test_default_symbol_is_portfolio():
    events = evaluate_risk_rules({
        "drawdown_pct": 10.0,
    })
    assert "Portfolio" in events[0]["description"]
