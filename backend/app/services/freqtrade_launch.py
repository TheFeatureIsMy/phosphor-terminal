"""Shared Freqtrade launch details for backtest and dry-run.

The timeframe on the rule package is the timeframe both commands select.
"""
from __future__ import annotations

from typing import Any


def rule_timeframe(dsl: dict[str, Any] | None) -> str:
    """Return the package timeframe, or 5m when the package does not name one."""
    if isinstance(dsl, dict):
        raw = str(dsl.get("timeframe") or "").strip()
        if raw:
            return raw
    return "5m"


def timeframe_overlay(timeframe: str) -> dict[str, str]:
    """Config fragment Freqtrade merges over the strategy class default."""
    return {"timeframe": timeframe}
