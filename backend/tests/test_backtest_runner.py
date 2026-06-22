"""Tests for FreqtradeBacktestRunner."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from app.services.backtest_runner import BacktestResult, FreqtradeBacktestRunner

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

SAMPLE_DSL: dict = {
    "schema_version": "2.5",
    "timeframe": "1h",
    "symbols": ["BTC/USDT"],
    "entry": {
        "logic": "AND",
        "rules": [
            {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": "<",
                "value": 30,
            }
        ],
    },
    "exit": {
        "logic": "OR",
        "rules": [
            {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": ">",
                "value": 70,
            }
        ],
    },
    "filters": [],
    "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
    "risk": {"stoploss": -0.05, "max_open_trades": 3},
    "metadata": {},
}


def _fake_result_json() -> dict:
    """Return a minimal freqtrade-style backtest result JSON."""
    return {
        "strategy": {
            "PulseDeskUniversalStrategy": {
                "profit_total": 0.125,
                "sharpe": 1.45,
                "max_drawdown": 0.08,
                "wins": 12,
                "trade_count": 20,
                "profit_factor": 1.8,
                "holding_avg": "2:30:00",
                "best_trade": 0.05,
                "worst_trade": -0.03,
                "trades": [
                    {"pair": "BTC/USDT", "profit_ratio": 0.02, "open_date": "2024-01-01"},
                    {"pair": "BTC/USDT", "profit_ratio": -0.01, "open_date": "2024-01-02"},
                ],
            }
        }
    }


@pytest.fixture()
def ft_env(tmp_path: Path):
    """Set up a minimal freqtrade directory tree and return the runner."""
    ft_dir = tmp_path / "freqtrade"
    user_data = ft_dir / "user_data"
    strategies = user_data / "strategies"
    results_dir = user_data / "backtest_results"

    for d in (strategies, results_dir):
        d.mkdir(parents=True)

    # Minimal base config
    base_config = user_data / "config.json"
    base_config.write_text(json.dumps({"exchange": {"name": "binance"}}), encoding="utf-8")

    # Placeholder start.py
    start_py = ft_dir / "start.py"
    start_py.write_text("# placeholder", encoding="utf-8")

    runner = FreqtradeBacktestRunner(freqtrade_dir=ft_dir)
    return runner, ft_dir, results_dir


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestRunSuccess:
    """test_run_success — subprocess returns 0, result JSON exists."""

    def test_run_success(self, ft_env):
        runner, ft_dir, results_dir = ft_env

        # Pre-create the result JSON that freqtrade would produce.
        result_file = results_dir / "backtest-result-run123.json"
        result_file.write_text(json.dumps(_fake_result_json()), encoding="utf-8")

        fake_proc = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="ok\n", stderr=""
        )

        with patch("app.services.backtest_runner.subprocess.run", return_value=fake_proc):
            result = runner.run(
                dsl=SAMPLE_DSL,
                timerange="20240101-20240201",
                symbols=["BTC/USDT"],
                run_id="run123",
            )

        assert result.success is True
        assert result.exit_code == 0

        # Metrics parsed from fake result
        m = result.metrics
        assert m.total_return_pct == pytest.approx(12.5)
        assert m.sharpe_ratio == pytest.approx(1.45)
        assert m.max_drawdown_pct == pytest.approx(8.0)
        assert m.win_rate == pytest.approx(12 / 20)
        assert m.profit_factor == pytest.approx(1.8)
        assert m.total_trades == 20
        assert m.avg_trade_duration == "2:30:00"
        assert m.best_trade_pct == pytest.approx(5.0)
        assert m.worst_trade_pct == pytest.approx(-3.0)

        # Trades list should be populated
        assert len(result.trades) == 2
        assert result.raw_result["strategy"]["PulseDeskUniversalStrategy"]["trade_count"] == 20


class TestRunFailureNonzeroExit:
    """test_run_failure_nonzero_exit — subprocess returns exit code 1."""

    def test_run_failure_nonzero_exit(self, ft_env):
        runner, ft_dir, results_dir = ft_env

        fake_proc = subprocess.CompletedProcess(
            args=[],
            returncode=1,
            stdout="",
            stderr="Error: Exchange binance not available\n",
        )

        with patch("app.services.backtest_runner.subprocess.run", return_value=fake_proc):
            result = runner.run(
                dsl=SAMPLE_DSL,
                timerange="20240101-20240201",
                symbols=["BTC/USDT"],
                run_id="fail1",
            )

        assert result.success is False
        assert result.exit_code == 1
        assert "Exchange binance not available" in result.error_message
        assert result.stderr == "Error: Exchange binance not available\n"


class TestRunTimeout:
    """test_run_timeout — subprocess raises TimeoutExpired."""

    def test_run_timeout(self, ft_env):
        runner, ft_dir, results_dir = ft_env

        exc = subprocess.TimeoutExpired(cmd=["python", "start.py"], timeout=600)
        exc.stdout = ""
        exc.stderr = ""

        with patch("app.services.backtest_runner.subprocess.run", side_effect=exc):
            result = runner.run(
                dsl=SAMPLE_DSL,
                timerange="20240101-20240201",
                symbols=["BTC/USDT"],
                run_id="timeout1",
                timeout_sec=600,
            )

        assert result.success is False
        assert result.exit_code == -1
        assert "timed out" in result.error_message.lower()
        assert "600" in result.error_message


class TestRulesFileWritten:
    """test_rules_file_written — the strategy_rules JSON is written to disk."""

    def test_rules_file_written(self, ft_env):
        runner, ft_dir, results_dir = ft_env

        fake_proc = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )

        with patch("app.services.backtest_runner.subprocess.run", return_value=fake_proc):
            runner.run(
                dsl=SAMPLE_DSL,
                timerange="20240101-20240201",
                symbols=["BTC/USDT"],
                run_id="rulecheck",
            )

        rules_path = ft_dir / "user_data" / "strategies" / "strategy_rules_rulecheck.json"
        assert rules_path.exists(), f"Expected rules file at {rules_path}"

        written = json.loads(rules_path.read_text(encoding="utf-8"))
        assert written == SAMPLE_DSL
        assert written["schema_version"] == "2.5"
        assert written["entry"]["rules"][0]["indicator"] == "rsi"


class TestConfigCleanup:
    """test_config_cleanup — temp config file is removed after run completes."""

    def test_config_cleanup(self, ft_env):
        runner, ft_dir, results_dir = ft_env

        created_configs: list[str] = []

        original_run = subprocess.run

        def capture_config(cmd, **kwargs):
            # The --config argument is right after the flag
            for i, arg in enumerate(cmd):
                if arg == "--config" and i + 1 < len(cmd):
                    created_configs.append(cmd[i + 1])
            return subprocess.CompletedProcess(
                args=cmd, returncode=0, stdout="", stderr=""
            )

        with patch("app.services.backtest_runner.subprocess.run", side_effect=capture_config):
            runner.run(
                dsl=SAMPLE_DSL,
                timerange="20240101-20240201",
                symbols=["BTC/USDT"],
                run_id="cleanup",
            )

        # A config should have been created and then cleaned up
        assert len(created_configs) == 1, "Expected exactly one config path captured"
        config_path = Path(created_configs[0])
        assert not config_path.exists(), (
            f"Temp config {config_path} should have been cleaned up after run"
        )


# ---------------------------------------------------------------------------
# Slippage tests (Task 2)
# ---------------------------------------------------------------------------


def test_build_config_applies_slippage_to_fee(tmp_path):
    runner = FreqtradeBacktestRunner(freqtrade_dir=tmp_path)
    config_path = runner._build_config(
        symbols=["BTC/USDT"],
        initial_capital=10000,
        stake_amount=100,
        max_open_trades=5,
        exchange="binance",
        fee=0.0005,
        slippage_bps=3.0,
        run_id="test",
    )
    config = json.loads(Path(config_path).read_text())
    # 0.0005 + 3/10000 = 0.0008
    assert abs(config["trading_fee"] - 0.0008) < 1e-9


def test_build_config_without_slippage_keeps_fee(tmp_path):
    runner = FreqtradeBacktestRunner(freqtrade_dir=tmp_path)
    config_path = runner._build_config(
        symbols=["BTC/USDT"],
        initial_capital=10000,
        stake_amount=100,
        max_open_trades=5,
        exchange="binance",
        fee=0.0005,
        slippage_bps=None,
        run_id="test",
    )
    config = json.loads(Path(config_path).read_text())
    assert config["trading_fee"] == 0.0005
