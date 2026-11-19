"""The backtest and dry-run commands select the rule package timeframe."""
import json
import zipfile

from app.services.backtest_runner import FreqtradeBacktestRunner
from app.services.dryrun_manager import DryRunProcessManager
from app.services.freqtrade_launch import rule_timeframe


PACKAGE = {
    "schema_version": "2.5",
    "timeframe": "15m",
    "symbols": ["BTC/USDT"],
    "entry": {"logic": "AND", "rules": []},
    "exit": {"logic": "OR", "rules": []},
    "risk": {"stoploss": -0.08},
}


def test_backtest_and_dryrun_commands_select_15m():
    timeframe = rule_timeframe(PACKAGE)
    runner = FreqtradeBacktestRunner()
    backtest = runner.backtest_command(
        config_path="/tmp/bt.json",
        timerange="20250601-20251031",
        export_filename="backtest-result-demo",
        timeframe=timeframe,
    )
    manager = DryRunProcessManager()
    dryrun = manager.trade_command(config_path="/tmp/dry.json", timeframe=timeframe)
    print("BACKTEST", " ".join(backtest))
    print("DRYRUN", " ".join(dryrun))
    assert backtest[backtest.index("--timeframe") + 1] == "15m"
    overlay = next(part for part in dryrun if part.endswith("timeframe-15m.json"))
    assert overlay.endswith("timeframe-15m.json")
    assert "15m" in " ".join(backtest)
    assert "15m" in " ".join(dryrun)


def test_zip_result_exposes_closed_trades_win_rate_and_absolute_profit(tmp_path):
    runner = FreqtradeBacktestRunner(freqtrade_dir=tmp_path / "freqtrade")
    results = runner._user_data / "backtest_results"
    results.mkdir(parents=True)
    payload = {
        "strategy": {
            "PulseDeskUniversalStrategy": {
                "total_trades": 56,
                "wins": 40,
                "profit_total_abs": 3.95714062,
                "profit_total": 0.000395714,
                "trades": [],
            }
        }
    }
    zip_path = results / "backtest-result-demo.zip"
    with zipfile.ZipFile(zip_path, "w") as archive:
        archive.writestr("backtest-result-demo.json", json.dumps(payload))
    parsed = runner._parse_result("backtest-result-demo")
    assert parsed.metrics.total_trades == 56
    assert parsed.metrics.win_rate == 40 / 56
    assert parsed.metrics.absolute_profit == 3.95714062
