import json
import signal
from unittest.mock import MagicMock, patch

import pytest

from app.services.dryrun_manager import DryRunProcessManager, DryRunStartResult

VALID_DSL = {
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


def _make_manager(tmp_path):
    ft_dir = tmp_path / "freqtrade"
    user_data = ft_dir / "user_data"
    strategies = user_data / "strategies"
    strategies.mkdir(parents=True)
    (user_data / "config.json").write_text('{"exchange": {"name": "binance"}}')
    (ft_dir / "start.py").write_text("# placeholder")
    (user_data / "logs").mkdir()
    manager = DryRunProcessManager(freqtrade_dir=ft_dir)
    return manager, ft_dir


@patch("subprocess.Popen")
def test_start_writes_rules_and_config(mock_popen, tmp_path):
    manager, ft_dir = _make_manager(tmp_path)

    mock_process = MagicMock()
    mock_process.pid = 99999
    mock_process.poll.return_value = None
    mock_popen.return_value = mock_process

    with patch.object(manager, "_wait_for_ping", return_value=True):
        result = manager.start(
            dsl=VALID_DSL,
            symbols=["BTC/USDT"],
            stake_amount=100,
            max_open_trades=3,
            initial_wallet=1000,
            exchange="binance",
            api_port=8080,
            run_id="test-run-001",
            ping_timeout=5,
        )

    assert isinstance(result, DryRunStartResult)
    assert result.pid == 99999

    rules_path = result.rules_path
    assert rules_path is not None
    from pathlib import Path

    rules_file = Path(rules_path)
    assert rules_file.exists()
    rules_content = json.loads(rules_file.read_text())
    assert rules_content == VALID_DSL


@patch("os.kill")
@patch("subprocess.Popen")
def test_start_ping_timeout_kills_process(mock_popen, mock_kill, tmp_path):
    manager, ft_dir = _make_manager(tmp_path)

    mock_process = MagicMock()
    mock_process.pid = 88888
    mock_process.poll.return_value = None
    mock_popen.return_value = mock_process

    with patch.object(manager, "_wait_for_ping", return_value=False):
        with pytest.raises(RuntimeError, match="failed to become ready"):
            manager.start(
                dsl=VALID_DSL,
                symbols=["BTC/USDT"],
                stake_amount=100,
                max_open_trades=3,
                initial_wallet=1000,
                exchange="binance",
                api_port=8081,
                run_id="test-run-002",
                ping_timeout=5,
            )

    mock_kill.assert_any_call(88888, signal.SIGKILL)


@patch("os.kill")
def test_stop_sends_sigterm(mock_kill):
    manager = DryRunProcessManager.__new__(DryRunProcessManager)

    mock_kill.side_effect = lambda pid, sig: None

    with patch.object(
        manager, "is_running", side_effect=[True, False, False]
    ):
        result = manager.stop(
            pid=12345,
            config_path="/tmp/fake_config.json",
            api_url=None,
        )

    mock_kill.assert_any_call(12345, signal.SIGTERM)


def test_is_running_true():
    manager = DryRunProcessManager.__new__(DryRunProcessManager)

    with patch("os.kill") as mock_kill:
        mock_kill.return_value = None
        assert manager.is_running(pid=12345) is True
    mock_kill.assert_called_with(12345, 0)


def test_is_running_false():
    manager = DryRunProcessManager.__new__(DryRunProcessManager)

    with patch("os.kill") as mock_kill:
        mock_kill.side_effect = ProcessLookupError
        assert manager.is_running(pid=12345) is False
    mock_kill.assert_called_with(12345, 0)
