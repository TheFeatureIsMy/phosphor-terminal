"""PulseDeskUniversalStrategy — fixed IStrategy template driven by DSL rules.json.

Per ADR-001: no eval, no exec, no code generation, no AI calls.
All entry/exit logic comes from the validated DSL JSON.
Fail-closed: any exception → no entry signal; exits still allowed.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from freqtrade.strategy.interface import IStrategy

logger = logging.getLogger(__name__)

RULES_PATH_ENV = "PULSEDESK_RULES_PATH"
DEFAULT_RULES_FILENAME = "strategy_rules.json"


class PulseDeskUniversalStrategy(IStrategy):
    INTERFACE_VERSION = 3

    # ── Freqtrade required class-level defaults ─────────────────────
    timeframe = "5m"
    stoploss = -0.10
    trailing_stop = False
    trailing_stop_positive = None
    trailing_stop_positive_offset = 0.0
    minimal_roi = {"0": 100}
    process_only_new_candles = True

    startup_candle_count: int = 50

    # ── Internal state ──────────────────────────────────────────────
    _rules_cache: dict[str, Any] | None = None
    _rules_mtime: float = 0.0
    _rules_hash: str = ""
    _safe_hold: bool = False
    _safe_hold_reason: str = ""
    _indicator_cache: dict[str, pd.Series] = {}

    # ── Snapshot mode state ─────────────────────────────────────────
    _snapshot_client = None
    _snapshot_guard = None
    _snapshot_mode: bool = False
    _snapshot_cache: dict[str, dict] = {}

    def _rules_path(self) -> Path:
        env = os.environ.get(RULES_PATH_ENV)
        if env:
            return Path(env)
        return Path(__file__).parent / DEFAULT_RULES_FILENAME

    def _load_rules(self) -> dict[str, Any] | None:
        path = self._rules_path()
        if not path.exists():
            logger.error("rules file not found: %s", path)
            return None
        try:
            raw = path.read_text(encoding="utf-8")
            rules = json.loads(raw)
            h = hashlib.sha256(raw.encode("utf-8")).hexdigest()
            return {"data": rules, "hash": h, "mtime": path.stat().st_mtime}
        except Exception:
            logger.exception("failed to read/parse rules file: %s", path)
            return None

    def _try_reload_rules(self) -> None:
        path = self._rules_path()
        try:
            mtime = path.stat().st_mtime
        except OSError:
            if self._rules_cache is None:
                self._enter_safe_hold("rules file missing")
            return

        if mtime == self._rules_mtime and self._rules_cache is not None:
            return

        result = self._load_rules()
        if result is None:
            self._enter_safe_hold("rules file unreadable")
            return

        if result["hash"] == self._rules_hash and self._rules_cache is not None:
            self._rules_mtime = result["mtime"]
            return

        rules = result["data"]
        validation = self._validate_rules(rules)
        if not validation["valid"]:
            self._enter_safe_hold(f"DSL validation failed: {validation['reason']}")
            return

        self._rules_cache = rules
        self._rules_mtime = result["mtime"]
        self._rules_hash = result["hash"]
        self._safe_hold = False
        self._safe_hold_reason = ""
        self._apply_risk_config(rules)
        self._indicator_cache = {}
        logger.info("rules reloaded: hash=%s", self._rules_hash[:12])

    def _validate_rules(self, rules: dict) -> dict:
        try:
            from app.services.dsl_validator import DSLValidator
            report = DSLValidator().validate(rules)
            if not report.valid:
                reasons = "; ".join(e.message for e in report.errors[:3])
                return {"valid": False, "reason": reasons}
            return {"valid": True, "reason": ""}
        except ImportError:
            return self._validate_rules_minimal(rules)
        except Exception:
            logger.exception("validation error")
            return {"valid": False, "reason": "validation exception"}

    def _validate_rules_minimal(self, rules: dict) -> dict:
        sv = rules.get("schema_version")
        if sv != "2.5":
            return {"valid": False, "reason": f"unsupported schema_version: {sv}"}
        if "entry" not in rules or "exit" not in rules:
            return {"valid": False, "reason": "missing entry or exit group"}
        if "risk" not in rules:
            return {"valid": False, "reason": "missing risk config"}
        return {"valid": True, "reason": ""}

    def _apply_risk_config(self, rules: dict) -> None:
        risk = rules.get("risk", {})
        if "stoploss" in risk:
            self.stoploss = float(risk["stoploss"])
        if risk.get("trailing_stop") is True:
            self.trailing_stop = True
            if risk.get("trailing_stop_positive") is not None:
                self.trailing_stop_positive = float(risk["trailing_stop_positive"])
            if risk.get("trailing_stop_positive_offset") is not None:
                self.trailing_stop_positive_offset = float(risk["trailing_stop_positive_offset"])
        else:
            self.trailing_stop = False
        tf = rules.get("timeframe")
        if tf:
            self.timeframe = tf

    def _enter_safe_hold(self, reason: str) -> None:
        if not self._safe_hold:
            logger.warning("entering safe_hold: %s", reason)
        self._safe_hold = True
        self._safe_hold_reason = reason

    # ── Freqtrade lifecycle ─────────────────────────────────────────

    def bot_loop_start(self, current_time=None, **kwargs) -> None:
        if self._snapshot_client is None:
            self._init_snapshot_mode()

        if self._snapshot_mode:
            return
        self._try_reload_rules()

    def _init_snapshot_mode(self):
        try:
            from redis_snapshot_client import RedisSnapshotClient
            self._snapshot_client = RedisSnapshotClient()
            if self._snapshot_client.available:
                from runtime_snapshot_guard import RuntimeSnapshotGuard
                self._snapshot_mode = True
                self._snapshot_guard = RuntimeSnapshotGuard({
                    "max_snapshot_miss_ticks": 3,
                    "hard_disconnect_timeout_ms": 3000,
                    "fallback_stop_pct": 0.02,
                })
                logger.info("snapshot mode enabled")
            else:
                logger.info("redis unavailable, using legacy rules mode")
        except ImportError:
            logger.info("snapshot client not available, using legacy rules mode")

    def populate_indicators(self, dataframe: pd.DataFrame,
                            metadata: dict) -> pd.DataFrame:
        if self._safe_hold or self._rules_cache is None:
            return dataframe

        try:
            from app.services.dsl_interpreter import compute_all_indicators
            self._indicator_cache = compute_all_indicators(
                dataframe, self._rules_cache
            )
        except Exception:
            logger.exception("indicator computation failed")
            self._indicator_cache = {}

        return dataframe

    def populate_entry_trend(self, dataframe: pd.DataFrame,
                             metadata: dict) -> pd.DataFrame:
        dataframe["enter_long"] = 0

        if self._snapshot_mode:
            return self._snapshot_entry(dataframe, metadata)

        if self._safe_hold or self._rules_cache is None:
            return dataframe

        try:
            from app.services.dsl_interpreter import (
                evaluate_filters, evaluate_group,
            )
            cache = self._indicator_cache

            entry_group = self._rules_cache.get("entry", {})
            filters = self._rules_cache.get("filters", [])

            entry_signal = evaluate_group(dataframe, entry_group, cache)
            filter_signal = evaluate_filters(dataframe, filters, cache)

            combined = entry_signal & filter_signal
            dataframe.loc[combined, "enter_long"] = 1

        except Exception:
            logger.exception("entry evaluation failed — no entries")
            dataframe["enter_long"] = 0

        return dataframe

    def populate_exit_trend(self, dataframe: pd.DataFrame,
                            metadata: dict) -> pd.DataFrame:
        dataframe["exit_long"] = 0

        if self._rules_cache is None:
            return dataframe

        try:
            from app.services.dsl_interpreter import evaluate_group
            cache = self._indicator_cache

            exit_group = self._rules_cache.get("exit", {})
            exit_signal = evaluate_group(dataframe, exit_group, cache)
            dataframe.loc[exit_signal, "exit_long"] = 1

        except Exception:
            logger.exception("exit evaluation failed")
            dataframe["exit_long"] = 0

        return dataframe

    def _snapshot_entry(self, dataframe, metadata):
        from datetime import datetime, timezone
        pair = metadata["pair"]
        snapshot = self._snapshot_client.read_snapshot(
            self._get_strategy_id(), pair, self.timeframe
        )
        now = datetime.now(timezone.utc)
        guard_state = self._snapshot_guard.update_from_snapshot(pair, snapshot, now)

        if guard_state["state"] == "disconnect_protection":
            logger.warning("disconnect protection active for %s — blocking entries", pair)
            return dataframe

        if snapshot and snapshot.get("execution_plan", {}).get("decision") == "allow_trade":
            self._snapshot_cache[pair] = snapshot
            dataframe.loc[dataframe.index[-1], "enter_long"] = 1

        return dataframe

    def _get_strategy_id(self) -> str:
        if self._rules_cache and isinstance(self._rules_cache, dict) and "strategy" in self._rules_cache:
            return self._rules_cache["strategy"].get("id", "default")
        return os.environ.get("PULSEDESK_STRATEGY_ID", "default")

    def custom_stoploss(self, pair, trade, current_time, current_rate,
                        current_profit, **kwargs):
        if self._snapshot_mode and self._snapshot_guard:
            from datetime import datetime, timezone
            now = datetime.now(timezone.utc)

            emergency = self._snapshot_guard.should_emergency_close(
                pair, current_rate, "long", now
            )
            if emergency["close"]:
                logger.warning("emergency close for %s: %s", pair, emergency["reason"])
                return -0.001

            return self._snapshot_guard.get_fallback_stoploss(pair, current_rate)

        return self.stoploss
