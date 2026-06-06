"""DryRunProcessManager — start/stop Freqtrade dry-run subprocess."""
from __future__ import annotations

import json
import logging
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

import aiohttp

from app.config import settings

logger = logging.getLogger(__name__)

_BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent
_FREQTRADE_DIR = _BASE_DIR / "freqtrade"
_USER_DATA_DIR = _FREQTRADE_DIR / "user_data"
_STRATEGIES_DIR = _USER_DATA_DIR / "strategies"
_BASE_CONFIG = _USER_DATA_DIR / "config.json"
_START_PY = _FREQTRADE_DIR / "start.py"

DEFAULT_API_PORT = 8080
PING_TIMEOUT = 30
STOP_TIMEOUT = 10


class DryRunStartResult:
    def __init__(self, pid: int, api_port: int, api_url: str,
                 config_path: str, rules_path: str):
        self.pid = pid
        self.api_port = api_port
        self.api_url = api_url
        self.config_path = config_path
        self.rules_path = rules_path


class DryRunProcessManager:
    def __init__(
        self,
        freqtrade_dir: Path | None = None,
        python_executable: str | None = None,
    ) -> None:
        self._ft_dir = freqtrade_dir or _FREQTRADE_DIR
        self._user_data = self._ft_dir / "user_data"
        self._strategies = self._user_data / "strategies"
        self._base_config = self._user_data / "config.json"
        self._start_py = self._ft_dir / "start.py"
        self._python = python_executable or sys.executable

    def start(
        self,
        *,
        dsl: dict[str, Any],
        symbols: list[str],
        stake_amount: float = 100,
        max_open_trades: int = 5,
        initial_wallet: float = 10000,
        exchange: str = "binance",
        api_port: int = DEFAULT_API_PORT,
        run_id: str = "",
        ping_timeout: int = PING_TIMEOUT,
    ) -> DryRunStartResult:
        rules_path = self._write_rules(dsl, run_id)
        config_path = self._build_config(
            symbols=symbols,
            stake_amount=stake_amount,
            max_open_trades=max_open_trades,
            initial_wallet=initial_wallet,
            exchange=exchange,
            api_port=api_port,
            run_id=run_id,
        )

        log_dir = self._user_data / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        log_file_path = log_dir / f"dryrun_{run_id}.log"

        env = {**os.environ, "PULSEDESK_RULES_PATH": str(rules_path)}

        cmd = [
            self._python,
            str(self._start_py),
            "trade",
            "--config", str(config_path),
            "--strategy", "PulseDeskUniversalStrategy",
            "--user-data-dir", str(self._user_data),
        ]

        logger.info("starting dry-run: %s", " ".join(cmd))

        log_fh = open(log_file_path, "w")
        proc = subprocess.Popen(
            cmd,
            stdout=log_fh,
            stderr=subprocess.STDOUT,
            env=env,
            cwd=str(self._ft_dir),
        )

        api_url = f"http://127.0.0.1:{api_port}"

        if not self._wait_for_ping(api_url, timeout=ping_timeout, proc=proc):
            self._kill_process(proc.pid)
            log_fh.close()
            stderr_tail = ""
            try:
                stderr_tail = log_file_path.read_text()[-1000:]
            except Exception:
                pass
            raise RuntimeError(
                f"freqtrade dry-run failed to become ready within {ping_timeout}s. "
                f"Log tail: {stderr_tail}"
            )

        logger.info("dry-run started: pid=%d port=%d", proc.pid, api_port)

        return DryRunStartResult(
            pid=proc.pid,
            api_port=api_port,
            api_url=api_url,
            config_path=str(config_path),
            rules_path=str(rules_path),
        )

    def stop(self, pid: int, config_path: str | None = None,
             api_url: str | None = None) -> bool:
        if api_url:
            try:
                import asyncio
                loop = asyncio.new_event_loop()
                try:
                    loop.run_until_complete(self._stop_via_api(api_url))
                finally:
                    loop.close()
                time.sleep(2)
            except Exception:
                logger.warning("REST stop failed, falling back to signal")

        if self.is_running(pid):
            try:
                os.kill(pid, signal.SIGTERM)
                for _ in range(STOP_TIMEOUT):
                    time.sleep(1)
                    if not self.is_running(pid):
                        break
                else:
                    os.kill(pid, signal.SIGKILL)
                    time.sleep(1)
            except ProcessLookupError:
                pass

        if config_path:
            try:
                Path(config_path).unlink(missing_ok=True)
            except OSError:
                pass

        return not self.is_running(pid)

    def is_running(self, pid: int) -> bool:
        try:
            os.kill(pid, 0)
            return True
        except (ProcessLookupError, PermissionError):
            return False

    def _write_rules(self, dsl: dict[str, Any], run_id: str) -> Path:
        filename = f"strategy_rules_{run_id}.json" if run_id else "strategy_rules.json"
        path = self._strategies / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(dsl, indent=2, ensure_ascii=False), encoding="utf-8")
        return path

    def _build_config(
        self,
        symbols: list[str],
        stake_amount: float,
        max_open_trades: int,
        initial_wallet: float,
        exchange: str,
        api_port: int,
        run_id: str,
    ) -> Path:
        if self._base_config.exists():
            base = json.loads(self._base_config.read_text(encoding="utf-8"))
        else:
            base = {}

        config = {
            **base,
            "dry_run": True,
            "dry_run_wallet": initial_wallet,
            "stake_amount": stake_amount,
            "max_open_trades": max_open_trades,
            "trading_mode": "spot",
            "exchange": {
                **base.get("exchange", {}),
                "name": exchange,
                "pair_whitelist": symbols,
            },
            "api_server": {
                "enabled": True,
                "listen_ip_address": "127.0.0.1",
                "listen_port": api_port,
                "verbosity": "error",
                "enable_openapi": False,
                "jwt_secret_key": f"pulsedesk-dryrun-{run_id}",
                "CORS_origins": [],
                "username": settings.freqtrade_username,
                "password": settings.freqtrade_password,
            },
        }

        fd, path = tempfile.mkstemp(prefix=f"dryrun_config_{run_id}_", suffix=".json")
        with os.fdopen(fd, "w") as f:
            json.dump(config, f, indent=2)
        return Path(path)

    def _wait_for_ping(self, api_url: str, timeout: int, proc: subprocess.Popen) -> bool:
        import asyncio

        async def _ping():
            auth = aiohttp.BasicAuth(settings.freqtrade_username, settings.freqtrade_password)
            deadline = time.time() + timeout
            while time.time() < deadline:
                if proc.poll() is not None:
                    return False
                try:
                    ct = aiohttp.ClientTimeout(total=2)
                    async with aiohttp.ClientSession(timeout=ct) as session:
                        async with session.get(f"{api_url}/api/v1/ping", auth=auth) as resp:
                            if resp.status == 200:
                                return True
                except Exception:
                    pass
                await asyncio.sleep(1)
            return False

        loop = asyncio.new_event_loop()
        try:
            return loop.run_until_complete(_ping())
        finally:
            loop.close()

    async def _stop_via_api(self, api_url: str) -> None:
        auth = aiohttp.BasicAuth(settings.freqtrade_username, settings.freqtrade_password)
        ct = aiohttp.ClientTimeout(total=5)
        async with aiohttp.ClientSession(timeout=ct) as session:
            async with session.post(f"{api_url}/api/v1/stop", auth=auth) as resp:
                logger.info("REST stop response: %d", resp.status)

    def _kill_process(self, pid: int) -> None:
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
