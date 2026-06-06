from __future__ import annotations
from typing import Any


def is_v25(dsl: dict[str, Any]) -> bool:
    return dsl.get("schema_version") == "2.5"


def is_v30(dsl: dict[str, Any]) -> bool:
    return dsl.get("schema_version") == "3.0"


def migrate_v25_to_v30(dsl: dict[str, Any]) -> dict[str, Any]:
    symbols = dsl.get("symbols", [])
    symbol = symbols[0] if symbols else "UNKNOWN/USDT"
    timeframe = dsl.get("timeframe", "5m")
    risk = dsl.get("risk", {})
    pos = dsl.get("position_sizing", {})

    stoploss_abs = abs(risk.get("stoploss", -0.05))

    return {
        "schema_version": "3.0",
        "strategy": {
            "id": f"migrated_{symbol.replace('/', '_').lower()}",
            "name": f"Migrated {symbol}",
            "symbol": symbol,
            "timeframe": timeframe,
            "mode": "auto",
        },
        "entry_logic": dsl.get("entry", {"logic": "AND", "rules": []}),
        "exit_logic": dsl.get("exit", {"logic": "AND", "rules": []}),
        "filters": dsl.get("filters", []),
        "stop_policy": {
            "mode": "structure_invalidated",
            "fallback_stop_pct": stoploss_abs,
            "max_stop_distance_pct": min(stoploss_abs * 1.5, 0.1),
        },
        "position_policy": {
            "risk_per_trade": 0.01,
            "max_position_pct": pos.get("position_pct", 0.1),
        },
        "metadata": dsl.get("metadata", {}),
    }
