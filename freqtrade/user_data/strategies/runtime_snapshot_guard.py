from __future__ import annotations

import logging
from datetime import datetime

logger = logging.getLogger(__name__)


class RuntimeSnapshotGuard:
    def __init__(self, config: dict):
        self._config = config
        self._miss_count: dict[str, int] = {}
        self._last_snapshot_at: dict[str, datetime] = {}
        self._last_valid_stop: dict[str, float] = {}
        self._last_entry_price: dict[str, float] = {}

    def update_from_snapshot(self, pair: str, snapshot: dict | None, now: datetime) -> dict:
        if snapshot and snapshot.get("execution_plan", {}).get("stop_price"):
            was_disconnected = self._miss_count.get(pair, 0) >= self._config.get("max_snapshot_miss_ticks", 3)
            self._miss_count[pair] = 0
            self._last_snapshot_at[pair] = now
            self._last_valid_stop[pair] = snapshot["execution_plan"]["stop_price"]
            self._last_entry_price.setdefault(pair, snapshot.get("execution_plan", {}).get("entry_price"))
            result = {
                "state": "healthy",
                "stop_price": self._last_valid_stop[pair],
            }
            if was_disconnected:
                result["reconnected"] = True
            return result

        self._miss_count[pair] = self._miss_count.get(pair, 0) + 1
        max_miss = self._config.get("max_snapshot_miss_ticks", 3)
        emergency_miss = self._config.get("emergency_miss_ticks", 6)

        if self._miss_count[pair] >= emergency_miss:
            return {
                "state": "emergency",
                "stop_price": self._last_valid_stop.get(pair),
                "reason": "emergency_threshold_exceeded",
            }

        if self._miss_count[pair] >= max_miss:
            return {
                "state": "disconnect_protection",
                "stop_price": self._last_valid_stop.get(pair),
                "reason": "runtime_snapshot_missing",
            }

        # Degraded: tighten stop
        stop = self._last_valid_stop.get(pair)
        entry = self._last_entry_price.get(pair)
        tighten = self._config.get("tighten_factor", 0.7)
        if stop and entry and entry != stop:
            tightened = entry + (stop - entry) * tighten
            stop = tightened

        return {
            "state": "degraded",
            "stop_price": stop,
            "reason": "snapshot_temporarily_missing",
        }

    def should_emergency_close(self, pair: str, current_rate: float,
                                trade_direction: str, now: datetime) -> dict:
        emergency_miss = self._config.get("emergency_miss_ticks", 6)
        max_miss = self._config.get("max_snapshot_miss_ticks", 3)

        if self._miss_count.get(pair, 0) < max_miss:
            return {"close": False}

        # Emergency threshold: force close regardless of price
        if self._miss_count.get(pair, 0) >= emergency_miss:
            return {"close": True, "reason": "emergency_threshold_force_close"}

        stop_price = self._last_valid_stop.get(pair)

        if not stop_price:
            return {"close": True, "reason": "no_valid_stop_under_disconnect"}

        if trade_direction == "long" and current_rate <= stop_price:
            return {"close": True, "reason": "last_valid_stop_triggered"}

        if trade_direction == "short" and current_rate >= stop_price:
            return {"close": True, "reason": "last_valid_stop_triggered"}

        last_at = self._last_snapshot_at.get(pair)
        if last_at:
            elapsed_ms = (now - last_at).total_seconds() * 1000
            timeout = self._config.get("hard_disconnect_timeout_ms", 3000)
            if elapsed_ms > timeout:
                return {"close": True, "reason": "hard_disconnect_timeout"}

        return {"close": False}

    def detect_reconnection(self, pair: str) -> bool:
        return self._miss_count.get(pair, 0) == 0 and pair in self._last_valid_stop

    def get_fallback_stoploss(self, pair: str, current_rate: float) -> float:
        stop_price = self._last_valid_stop.get(pair)
        if stop_price and current_rate > 0:
            return (stop_price / current_rate) - 1
        return -self._config.get("fallback_stop_pct", 0.02)
