"""Launch a live-small Freqtrade process against the official live Spot host.

The config is built from generate_config_preview. It never copies the demo
config, never includes a demo API key, and never passes --dry-run.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from app.schemas.live_small import CapitalPoolParams
from app.services.live_small.config_generator import generate_config_preview, validate_config_safety
from app.services.providers.categories.cex.binance import ccxt_spot_api_urls, rest_base_for_mode

LIVE_SMALL_API_PORT = 8091
_REPO = Path(__file__).resolve().parents[4]
_FREQTRADE = _REPO / "freqtrade"


def build_live_small_config(
    dsl: dict[str, Any],
    pool: CapitalPoolParams,
    *,
    exchange_name: str = "binance",
    api_port: int = LIVE_SMALL_API_PORT,
    run_id: str = "",
    max_open_trades_cap: int | None = None,
) -> dict[str, Any]:
    """Official live Spot map. Refuses the demo host and a dry-run flag."""
    if api_port == 8080:
        raise RuntimeError("live_small must not bind the demo bot port 8080")
    preview = generate_config_preview(
        dsl, pool, exchange_name, max_open_trades_cap=max_open_trades_cap,
    )
    errors = validate_config_safety(preview, pool)
    if errors:
        raise RuntimeError("; ".join(errors))
    urls = dict(preview.exchange_ccxt_urls)
    if urls != ccxt_spot_api_urls("live") or preview.exchange_rest_base != rest_base_for_mode("live"):
        raise RuntimeError("live_small config must use the official live spot map")
    if any("demo-api.binance.com" in url for url in urls.values()):
        raise RuntimeError("refusing demo host")
    if preview.dry_run is not False:
        raise RuntimeError("dry_run must be false")
    symbols = preview.pair_whitelist or ["BTC/USDT"]
    return {
        "dry_run": False,
        "trading_mode": "spot",
        "stake_currency": preview.stake_currency,
        "stake_amount": preview.stake_amount,
        "max_open_trades": preview.max_open_trades,
        "stoploss": preview.stoploss,
        "trailing_stop": preview.trailing_stop,
        "timeframe": str(dsl.get("timeframe") or "15m"),
        "exchange": {
            "name": exchange_name,
            "key": "",
            "secret": "",
            "ccxt_config": {
                "enableRateLimit": True,
                "options": {"defaultType": "spot"},
                "urls": {"api": urls},
            },
            "pair_whitelist": symbols,
            "pair_blacklist": [],
        },
        "pairlists": [{"method": "StaticPairList"}],
        "api_server": {
            "enabled": True,
            "listen_ip_address": "127.0.0.1",
            "listen_port": api_port,
            "verbosity": "error",
            "enable_openapi": False,
            "jwt_secret_key": f"pulsedesk-live-small-{run_id or 'run'}",
            "CORS_origins": [],
            "username": "freqtrade",
            "password": "freqtrade",
        },
        "initial_state": "running",
        "bot_name": f"live-small-{run_id or 'run'}",
        "cancel_open_orders_on_exit": True,
    }


class LiveSmallLauncher:
    """Process sink. start() is the only place a live trade process is spawned."""

    def __init__(self, freqtrade_dir: Path | None = None, python_executable: str | None = None) -> None:
        self._ft_dir = freqtrade_dir or _FREQTRADE
        self._python = python_executable or sys.executable

    def trade_command(self, config_path: str) -> list[str]:
        return [
            self._python,
            str(self._ft_dir / "start.py"),
            "trade",
            "--config",
            config_path,
            "--strategy",
            "PulseDeskUniversalStrategy",
            "--user-data-dir",
            str(self._ft_dir / "user_data"),
        ]

    def start(self, config: dict[str, Any], *, run_id: str) -> dict[str, Any]:
        urls = ((config.get("exchange") or {}).get("ccxt_config") or {}).get("urls", {}).get("api") or {}
        if config.get("dry_run") is not False:
            raise RuntimeError("dry_run must be false")
        if any("demo-api.binance.com" in str(url) for url in urls.values()):
            raise RuntimeError("refusing demo host")
        if urls != ccxt_spot_api_urls("live"):
            raise RuntimeError("refusing a spot map that is not the official live host")
        port = int((config.get("api_server") or {}).get("listen_port") or 0)
        if port == 8080:
            raise RuntimeError("live_small must not bind the demo bot port 8080")
        command = self.trade_command(self._write_config(config, run_id))
        if "--dry-run" in command:
            raise RuntimeError("live launch must not pass --dry-run")
        proc = subprocess.Popen(
            command,
            cwd=str(self._ft_dir),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return {
            "pid": proc.pid,
            "api_port": port,
            "config_path": command[command.index("--config") + 1],
            "exchange_urls": dict(urls),
            "dry_run": False,
        }

    def _write_config(self, config: dict[str, Any], run_id: str) -> str:
        fd, path = tempfile.mkstemp(prefix=f"live_small_{run_id}_", suffix=".json")
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as handle:
            json.dump(config, handle)
        return path
