"""FreqtradeBacktestRunner — subprocess wrapper for freqtrade backtesting."""
from __future__ import annotations

import json
import logging
import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from app.config import settings
from app.services.freqtrade_launch import rule_timeframe

logger = logging.getLogger(__name__)

_BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent
_FREQTRADE_DIR = _BASE_DIR / "freqtrade"
_USER_DATA_DIR = _FREQTRADE_DIR / "user_data"
_STRATEGIES_DIR = _USER_DATA_DIR / "strategies"
_RESULTS_DIR = _USER_DATA_DIR / "backtest_results"
_BASE_CONFIG = _USER_DATA_DIR / "config.json"
_START_PY = _FREQTRADE_DIR / "start.py"


@dataclass
class BacktestMetrics:
    total_return_pct: float = 0.0
    sharpe_ratio: float = 0.0
    max_drawdown_pct: float = 0.0
    win_rate: float = 0.0
    profit_factor: float = 0.0
    total_trades: int = 0
    absolute_profit: float = 0.0
    avg_trade_duration: str = ""
    best_trade_pct: float = 0.0
    worst_trade_pct: float = 0.0


@dataclass
class BacktestResult:
    success: bool
    metrics: BacktestMetrics = field(default_factory=BacktestMetrics)
    trades: list[dict[str, Any]] = field(default_factory=list)
    equity_curve: list[dict[str, Any]] = field(default_factory=list)
    raw_result: dict[str, Any] = field(default_factory=dict)
    stdout: str = ""
    stderr: str = ""
    exit_code: int = 0
    error_message: str = ""


class FreqtradeBacktestRunner:
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

    def run(
        self,
        *,
        dsl: dict[str, Any],
        timerange: str,
        symbols: list[str],
        initial_capital: float = 10000,
        stake_amount: float | int = 100,
        max_open_trades: int = 5,
        exchange: str = "binance",
        fee: float | None = None,
        timeout_sec: int = 600,
        run_id: str = "",
        slippage_bps: float | None = None,
    ) -> BacktestResult:
        rules_path = self._write_rules(dsl, run_id)
        timeframe = rule_timeframe(dsl)
        config_path = self._build_config(
            symbols=symbols,
            initial_capital=initial_capital,
            stake_amount=stake_amount,
            max_open_trades=max_open_trades,
            exchange=exchange,
            fee=fee,
            run_id=run_id,
            slippage_bps=slippage_bps,
        )
        export_filename = f"backtest-result-{run_id}" if run_id else "backtest-result"

        try:
            result = self._execute(
                config_path=str(config_path),
                rules_path=str(rules_path),
                timerange=timerange,
                export_filename=export_filename,
                timeframe=timeframe,
                timeout_sec=timeout_sec,
                run_id=run_id,
            )
        finally:
            self._cleanup(config_path)

        return result

    def _write_rules(self, dsl: dict[str, Any], run_id: str) -> Path:
        filename = f"strategy_rules_{run_id}.json" if run_id else "strategy_rules.json"
        path = self._strategies / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(dsl, indent=2, ensure_ascii=False), encoding="utf-8")
        logger.info("wrote rules file: %s", path)
        return path

    def _build_config(
        self,
        symbols: list[str],
        initial_capital: float,
        stake_amount: float | int,
        max_open_trades: int,
        exchange: str,
        fee: float | None,
        run_id: str,
        slippage_bps: float | None = None,
    ) -> Path:
        if self._base_config.exists():
            base = json.loads(self._base_config.read_text(encoding="utf-8"))
        else:
            base = {}

        config = {
            **base,
            "dry_run": True,
            "dry_run_wallet": initial_capital,
            "stake_amount": stake_amount,
            "max_open_trades": max_open_trades,
            "trading_mode": "spot",
            "exchange": {
                **base.get("exchange", {}),
                "name": exchange,
                "pair_whitelist": symbols,
            },
        }

        if fee is not None or slippage_bps is not None:
            effective_fee = fee if fee is not None else 0.0005
            if slippage_bps is not None:
                effective_fee = effective_fee + slippage_bps / 10000.0
            config["trading_fee"] = effective_fee

        config.pop("api_server", None)

        fd, path = tempfile.mkstemp(prefix=f"bt_config_{run_id}_", suffix=".json")
        with os.fdopen(fd, "w") as f:
            json.dump(config, f, indent=2)
        logger.info("wrote backtest config: %s", path)
        return Path(path)

    def backtest_command(
        self,
        *,
        config_path: str,
        timerange: str,
        export_filename: str,
        timeframe: str,
        results_dir: str | None = None,
    ) -> list[str]:
        """Argv the worker runs. Timeframe is the rule package timeframe."""
        directory = results_dir or str(self._user_data / "backtest_results")
        return [
            self._python,
            str(self._start_py),
            "backtesting",
            "--config", config_path,
            "--strategy", "PulseDeskUniversalStrategy",
            "--timeframe", timeframe,
            "--timerange", timerange,
            "--cache", "none",
            "--backtest-directory", directory,
            "--export", "trades",
            "--export-filename",
            str(Path(directory) / export_filename),
            "--user-data-dir", str(self._user_data),
        ]

    def _execute(
        self,
        config_path: str,
        rules_path: str,
        timerange: str,
        export_filename: str,
        timeframe: str,
        timeout_sec: int,
        run_id: str = "",
    ) -> BacktestResult:
        run_results = self._user_data / "backtest_results" / f"run_{run_id or 'adhoc'}"
        run_results.mkdir(parents=True, exist_ok=True)
        cmd = self.backtest_command(
            config_path=config_path,
            timerange=timerange,
            export_filename=export_filename,
            timeframe=timeframe,
            results_dir=str(run_results),
        )

        backend_dir = Path(__file__).resolve().parent.parent.parent
        ta_lib = Path.home() / ".local" / "ta-lib" / "lib"
        library_path = os.environ.get("DYLD_LIBRARY_PATH", "")
        if ta_lib.is_dir():
            library_path = os.pathsep.join([str(ta_lib), library_path]).rstrip(os.pathsep)
        env = {
            **os.environ,
            "PULSEDESK_RULES_PATH": rules_path,
            "PYTHONPATH": os.pathsep.join(
                [str(backend_dir), os.environ.get("PYTHONPATH", "")]
            ).rstrip(os.pathsep),
            "DYLD_LIBRARY_PATH": library_path,
        }

        logger.info("running freqtrade backtest: %s", " ".join(cmd))
        log_path = self._user_data / "logs" / f"backtest_{run_id or 'run'}.log"

        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout_sec,
                env=env,
                cwd=str(self._ft_dir),
            )
        except subprocess.TimeoutExpired as exc:
            self._write_run_log(log_path, cmd, exc.stdout or "", exc.stderr or "")
            return BacktestResult(
                success=False,
                stdout=exc.stdout or "",
                stderr=exc.stderr or "",
                exit_code=-1,
                error_message=f"freqtrade backtesting timed out after {timeout_sec}s",
            )

        self._write_run_log(log_path, cmd, proc.stdout, proc.stderr)
        if proc.returncode != 0:
            return BacktestResult(
                success=False,
                stdout=proc.stdout,
                stderr=proc.stderr,
                exit_code=proc.returncode,
                error_message=f"freqtrade exited with code {proc.returncode}: {proc.stderr[-500:] if proc.stderr else ''}",
            )

        parsed = self._parse_result(export_filename, results_dir=run_results)
        # Only ad-hoc runs may fall back to the shared results directory. A
        # real run must never parse another run's export.
        if (
            not run_id
            and not parsed.success
            and "no result file" in parsed.error_message
        ):
            fallback = self._parse_result(export_filename)
            if fallback.success:
                parsed = fallback
        parsed.stdout = proc.stdout
        parsed.stderr = proc.stderr
        parsed.exit_code = proc.returncode
        return parsed

    @staticmethod
    def _write_run_log(path: Path, cmd: list[str], stdout: str, stderr: str) -> None:
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(
                "command: " + " ".join(cmd) + "\n" + (stdout or "") + "\n" + (stderr or ""),
                encoding="utf-8",
            )
        except OSError:
            logger.warning("could not write backtest log %s", path)

    def _parse_result(self, export_filename: str, results_dir: Path | None = None) -> BacktestResult:
        directory = results_dir or (self._user_data / "backtest_results")
        prefixed = [path for path in directory.glob(f"{export_filename}*") if path.is_file()]
        pooled = prefixed or [
            path for path in directory.glob("backtest-result-*")
            if path.is_file() and not path.name.endswith(".meta.json")
        ]
        candidates = sorted(pooled, key=lambda path: path.stat().st_mtime, reverse=True)
        raw = None
        parse_error = ""
        for path in candidates:
            try:
                document = self._read_result_document(path)
            except (json.JSONDecodeError, OSError, KeyError) as exc:
                parse_error = str(exc)
                continue
            if document is not None:
                raw = document
                break

        if raw is None:
            if parse_error:
                return BacktestResult(
                    success=False,
                    error_message=f"failed to parse result file: {parse_error}",
                )
            return BacktestResult(
                success=False,
                error_message="backtest succeeded but no result file found",
            )

        strategy_data = raw.get("strategy", {})
        strat_key = next(iter(strategy_data), None)
        if not strat_key:
            strategy_data = raw.get("strategy_comparison", [{}])
            if isinstance(strategy_data, list) and strategy_data:
                s = strategy_data[0]
                metrics = BacktestMetrics(
                    total_return_pct=s.get("profit_total", 0) * 100,
                    total_trades=s.get("trades", 0),
                    win_rate=s.get("wins", 0) / max(s.get("trades", 1), 1),
                    max_drawdown_pct=s.get("max_drawdown", 0) * 100,
                    sharpe_ratio=s.get("sharpe", 0),
                )
                return BacktestResult(success=True, metrics=metrics, raw_result=raw)
            return BacktestResult(success=True, raw_result=raw)

        s = strategy_data[strat_key]
        trades_list = s.get("trades", [])
        closed, win_rate = self._closed_and_win_rate(s)
        metrics = BacktestMetrics(
            total_return_pct=float(s.get("profit_total") or 0) * 100,
            sharpe_ratio=float(s.get("sharpe") or 0),
            max_drawdown_pct=abs(float(s.get("max_drawdown") or 0)) * 100,
            win_rate=win_rate,
            profit_factor=float(s.get("profit_factor") or 0),
            total_trades=closed,
            absolute_profit=float(s.get("profit_total_abs") or 0),
            avg_trade_duration=s.get("holding_avg", "") or "",
            best_trade_pct=float(s.get("best_trade") or 0) * 100,
            worst_trade_pct=float(s.get("worst_trade") or 0) * 100,
        )

        normalized_trades = [
            self._normalize_trade(t) for t in trades_list
        ]
        equity_curve = self._build_equity_curve(normalized_trades, initial_capital=10000.0)

        return BacktestResult(
            success=True,
            metrics=metrics,
            trades=normalized_trades,
            equity_curve=equity_curve,
            raw_result=raw,
        )

    @staticmethod
    def _read_result_document(path: Path) -> dict[str, Any] | None:
        """Load a Freqtrade result JSON, including the JSON stored inside a zip."""
        if path.name.endswith(".meta.json") or not path.is_file():
            return None
        if path.suffix == ".zip":
            import zipfile
            with zipfile.ZipFile(path) as archive:
                for name in archive.namelist():
                    if not name.endswith(".json") or name.endswith("_config.json"):
                        continue
                    raw = json.loads(archive.read(name))
                    if isinstance(raw, dict) and "strategy" in raw:
                        return raw
            return None
        if path.suffix != ".json":
            return None
        raw = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(raw, dict) and ("strategy" in raw or "strategy_comparison" in raw):
            return raw
        return None

    @staticmethod
    def _closed_and_win_rate(summary: dict[str, Any]) -> tuple[int, float]:
        """Closed-trade count and win rate from a Freqtrade strategy summary.

        Current exports use total_trades. Older exports used trade_count.
        """
        closed = summary.get("total_trades")
        if closed is None:
            closed = summary.get("trade_count") or 0
        closed = int(closed or 0)
        wins = int(summary.get("wins") or 0)
        win_rate = (wins / closed) if closed else 0.0
        return closed, win_rate

    @staticmethod
    def _normalize_trade(t: dict[str, Any]) -> dict[str, Any]:
        """Map freqtrade trade dict keys to TradeRow schema keys."""
        direction = t.get("trade_direction") or ("short" if t.get("is_short") else "long")
        open_time = str(t.get("open_date", t.get("open_timestamp", "")))
        close_time = str(t.get("close_date", t.get("close_timestamp", "")))
        open_price = float(t.get("open_rate", t.get("entry_price", 0.0)) or 0.0)
        close_price = float(t.get("close_rate", t.get("exit_price", 0.0)) or 0.0)
        quantity = float(t.get("amount", t.get("stake_amount", 0.0)) or 0.0)
        profit = float(t.get("profit_abs", t.get("profit_amount", 0.0)) or 0.0)
        duration = str(t.get("trade_duration", t.get("holding_avg", "")))
        return {
            "open_time": open_time,
            "close_time": close_time,
            "pair": str(t.get("pair", "")),
            "side": direction,
            "open_price": open_price,
            "close_price": close_price,
            "quantity": quantity,
            "profit": profit,
            "duration": duration,
            "mtf_state": t.get("mtf_state"),
        }

    @staticmethod
    def _build_equity_curve(
        trades: list[dict[str, Any]], initial_capital: float = 10000.0
    ) -> list[dict[str, Any]]:
        """Derive a per-trade equity curve from normalized trades.

        Each point = cumulative capital after closing that trade.
        Drawdown = current equity minus running peak (<= 0).
        """
        curve: list[dict[str, Any]] = []
        equity = initial_capital
        peak = initial_capital
        for t in trades:
            equity += float(t.get("profit", 0.0))
            peak = max(peak, equity)
            drawdown = equity - peak  # <= 0
            curve.append({
                "timestamp": t.get("close_time", ""),
                "equity": round(equity, 6),
                "drawdown": round(drawdown, 6),
            })
        return curve

    def _cleanup(self, config_path: Path) -> None:
        try:
            config_path.unlink(missing_ok=True)
        except OSError:
            pass


# ── MTF Guard Replay Engine ──────────────────────────────────────────
@dataclass
class MTFGuardReplayStats:
    """Accumulated counters from replaying MTF Guard over backtest trades."""
    blocked_entries: int = 0
    reduced_size: int = 0
    temporary_violation_count: int = 0
    reclaim_confirmed_count: int = 0
    invalidated_count: int = 0
    false_breakout_avoided_count: int = 0
    pnl_delta: float = 0.0
    max_drawdown_delta: float = 0.0
    replay_events: list[dict[str, Any]] = field(default_factory=list)


class MTFGuardReplayEngine:
    """Replays MTF Guard evaluations over completed backtest trades.

    For each trade in the backtest result, simulates what the guard would
    have decided.  If guard would have blocked an entry that turned out to
    be a losing trade, that counts as a *false breakout avoided* and the
    pnl_delta is adjusted positively.
    """

    def __init__(self) -> None:
        from app.services.mtf_temporal_guard import MTFTemporalGuardService
        self._guard = MTFTemporalGuardService()

    def replay(
        self,
        trades: list[dict[str, Any]],
        *,
        symbol: str = "BTC/USDT",
        fast_timeframe: str = "5m",
        slow_timeframe: str = "1h",
        zone_top: float = 0.0,
        zone_bottom: float = 0.0,
        zone_direction: str = "bullish",
        guard_config: dict[str, Any] | None = None,
    ) -> MTFGuardReplayStats:
        """Replay guard over each trade to compute what-if stats.

        Parameters
        ----------
        trades : list[dict]
            Trade dicts from freqtrade backtest result.
        symbol, fast_timeframe, slow_timeframe :
            Market context for the guard.
        zone_top, zone_bottom, zone_direction :
            HTF structure zone to guard. When both are 0, we derive
            synthetic zones from trade entry prices.
        guard_config : dict, optional
            Extra guard config overrides.
        """
        import pandas as pd

        stats = MTFGuardReplayStats()
        self._guard.reset(f"backtest_replay_{symbol}")

        config = {
            "guard_id": f"backtest_replay_{symbol}",
            "fast_timeframe": fast_timeframe,
            "slow_timeframe": slow_timeframe,
            **(guard_config or {}),
        }

        cumulative_pnl_with_guard = 0.0
        cumulative_pnl_without_guard = 0.0
        max_dd_with_guard = 0.0
        max_dd_without_guard = 0.0
        peak_with = 0.0
        peak_without = 0.0

        for idx, trade in enumerate(trades):
            open_rate = trade.get("open_rate", trade.get("entry_price", 0.0))
            close_rate = trade.get("close_rate", trade.get("exit_price", 0.0))
            trade_pnl = trade.get("profit_abs", trade.get("profit_amount", 0.0))
            is_loss = (trade_pnl < 0) if trade_pnl else False

            # Build synthetic candle data for guard evaluation
            fast_df = pd.DataFrame([{
                "open": open_rate,
                "high": max(open_rate, close_rate) * 1.001,
                "low": min(open_rate, close_rate) * 0.999,
                "close": open_rate,  # at entry moment, close ~ open
                "volume": 100,
            }])
            slow_df = pd.DataFrame([
                {
                    "open": open_rate * 0.998,
                    "high": open_rate * 1.005,
                    "low": open_rate * 0.995,
                    "close": open_rate * 1.001,
                    "volume": 1000,
                },
                {
                    "open": open_rate * 1.001,
                    "high": open_rate * 1.006,
                    "low": open_rate * 0.994,
                    "close": open_rate,
                    "volume": 1000,
                },
            ])

            # Derive zone from trade price if not explicitly provided
            effective_zone_top = zone_top if zone_top > 0 else open_rate * 1.002
            effective_zone_bottom = zone_bottom if zone_bottom > 0 else open_rate * 0.998

            source_structure = {
                "zone_type": "order_block",
                "direction": zone_direction,
                "price_top": effective_zone_top,
                "price_bottom": effective_zone_bottom,
                "status": "active",
            }

            result = self._guard.evaluate(
                fast_tf_data=fast_df,
                slow_tf_data=slow_df,
                source_structure=source_structure,
                config=config,
            )

            guard_state = result.get("guard_state", "watching")
            action = result.get("action", "allow")
            reason_codes = result.get("reason_codes", [])

            entry_blocked = action in ("block_entry",)
            size_reduced = action in ("reduce_size",)

            # Track state counters
            if guard_state == "temporary_violation":
                stats.temporary_violation_count += 1
            elif guard_state == "confirmed":
                stats.reclaim_confirmed_count += 1
            elif guard_state == "invalidated":
                stats.invalidated_count += 1

            if entry_blocked:
                stats.blocked_entries += 1
                if is_loss:
                    stats.false_breakout_avoided_count += 1

            if size_reduced:
                stats.reduced_size += 1

            # PnL accounting: without guard, all trades count;
            # with guard, blocked trades are skipped
            cumulative_pnl_without_guard += trade_pnl
            if not entry_blocked:
                if size_reduced:
                    cumulative_pnl_with_guard += trade_pnl * 0.5
                else:
                    cumulative_pnl_with_guard += trade_pnl
            # else: blocked — no PnL contribution

            # Max drawdown tracking
            peak_without = max(peak_without, cumulative_pnl_without_guard)
            dd_without = peak_without - cumulative_pnl_without_guard
            max_dd_without_guard = max(max_dd_without_guard, dd_without)

            peak_with = max(peak_with, cumulative_pnl_with_guard)
            dd_with = peak_with - cumulative_pnl_with_guard
            max_dd_with_guard = max(max_dd_with_guard, dd_with)

            # Record replay event
            timestamp = trade.get("open_date", trade.get("entry_time", ""))
            stats.replay_events.append({
                "candle_index": idx,
                "timestamp": str(timestamp) if timestamp else None,
                "symbol": symbol,
                "fast_timeframe": fast_timeframe,
                "slow_timeframe": slow_timeframe,
                "guard_state": guard_state,
                "action": action,
                "reason_codes": reason_codes,
                "violation": result.get("violation", {}),
                "price_close": open_rate,
                "trade_would_enter": True,
                "entry_blocked": entry_blocked,
                "size_reduced": size_reduced,
            })

        stats.pnl_delta = cumulative_pnl_with_guard - cumulative_pnl_without_guard
        stats.max_drawdown_delta = max_dd_with_guard - max_dd_without_guard

        return stats
