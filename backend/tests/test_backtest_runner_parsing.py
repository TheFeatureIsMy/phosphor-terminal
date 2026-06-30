"""Tests for FreqtradeBacktestRunner result parsing — trade normalization + equity curve."""
from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import pytest

from app.services.backtest_runner import FreqtradeBacktestRunner, BacktestResult


def _freqtrade_raw():
    """A minimal freqtrade backtest export with 3 trades."""
    return {
        "strategy": {
            "PulseDeskUniversalStrategy": {
                "total_trades": 3,
                "trades": [
                    {
                        "open_date": "2026-01-01 00:00:00",
                        "close_date": "2026-01-01 02:00:00",
                        "pair": "BTC/USDT",
                        "trade_direction": "long",
                        "open_rate": 40000.0,
                        "close_rate": 40500.0,
                        "amount": 0.01,
                        "profit_abs": 5.0,
                        "profit_ratio": 0.0125,
                    },
                    {
                        "open_date": "2026-01-02 03:00:00",
                        "close_date": "2026-01-02 06:00:00",
                        "pair": "ETH/USDT",
                        "trade_direction": "short",
                        "open_rate": 3000.0,
                        "close_rate": 2950.0,
                        "amount": 0.5,
                        "profit_abs": 25.0,
                        "profit_ratio": 0.0167,
                    },
                    {
                        "open_date": "2026-01-03 09:00:00",
                        "close_date": "2026-01-03 12:00:00",
                        "pair": "BTC/USDT",
                        "trade_direction": "long",
                        "open_rate": 40500.0,
                        "close_rate": 40000.0,
                        "amount": 0.01,
                        "profit_abs": -5.0,
                        "profit_ratio": -0.0123,
                    },
                ],
                "profit_total": 0.000625,
                "max_drawdown": -0.02,
                "trade_count": 3,
                "wins": 2,
                "profit_factor": 6.0,
                "sharpe": 1.5,
                "holding_avg": "3h 0m",
                "best_trade": 0.0167,
                "worst_trade": -0.0123,
            }
        }
    }


def test_parse_result_normalizes_trade_keys(tmp_path):
    """Trades from freqtrade use open_date/open_rate/profit_abs; runner must
    normalize to open_time/open_price/profit to match TradeRow schema."""
    raw = _freqtrade_raw()
    runner = FreqtradeBacktestRunner()
    # Point user_data to tmp_path so _parse_result finds our file
    runner._user_data = tmp_path
    results_dir = tmp_path / "backtest_results"
    results_dir.mkdir()
    (results_dir / "result.json").write_text(json.dumps(raw))
    result = runner._parse_result("result")

    assert result.success
    assert len(result.trades) == 3
    t0 = result.trades[0]
    assert t0["open_time"] == "2026-01-01 00:00:00"
    assert t0["close_time"] == "2026-01-01 02:00:00"
    assert t0["pair"] == "BTC/USDT"
    assert t0["side"] == "long"
    assert t0["open_price"] == 40000.0
    assert t0["close_price"] == 40500.0
    assert t0["quantity"] == 0.01
    assert t0["profit"] == 5.0
    assert "duration" in t0
    assert "mtf_state" in t0  # may be None


def test_parse_result_short_side_mapping(tmp_path):
    """freqtrade trade_direction 'short' maps to side 'short'."""
    raw = _freqtrade_raw()
    runner = FreqtradeBacktestRunner()
    runner._user_data = tmp_path
    results_dir = tmp_path / "backtest_results"
    results_dir.mkdir()
    (results_dir / "result.json").write_text(json.dumps(raw))
    result = runner._parse_result("result")

    assert result.trades[1]["side"] == "short"


def test_parse_result_builds_equity_curve(tmp_path):
    """Runner must derive an equity_curve from trades, cumulative on initial capital."""
    raw = _freqtrade_raw()
    runner = FreqtradeBacktestRunner()
    runner._user_data = tmp_path
    results_dir = tmp_path / "backtest_results"
    results_dir.mkdir()
    (results_dir / "result.json").write_text(json.dumps(raw))
    result = runner._parse_result("result")

    assert len(result.equity_curve) >= 3
    # Each point has timestamp/equity/drawdown
    for p in result.equity_curve:
        assert "timestamp" in p
        assert "equity" in p
        assert "drawdown" in p
    # Equity is cumulative starting from initial capital (default 10000)
    # Trade 0 profit +5 → 10005, Trade 1 +25 → 10030, Trade 2 -5 → 10025
    assert result.equity_curve[0]["equity"] == pytest.approx(10005.0)
    assert result.equity_curve[1]["equity"] == pytest.approx(10030.0)
    assert result.equity_curve[2]["equity"] == pytest.approx(10025.0)


def test_parse_result_drawdown_nonpositive(tmp_path):
    """Drawdown values should be <= 0 (peak-to-trough is negative or zero)."""
    raw = _freqtrade_raw()
    runner = FreqtradeBacktestRunner()
    runner._user_data = tmp_path
    results_dir = tmp_path / "backtest_results"
    results_dir.mkdir()
    (results_dir / "result.json").write_text(json.dumps(raw))
    result = runner._parse_result("result")

    for p in result.equity_curve:
        assert p["drawdown"] <= 0
