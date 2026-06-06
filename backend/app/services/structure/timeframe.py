from __future__ import annotations

TIMEFRAME_RANK: dict[str, int] = {
    "1m": 1,
    "3m": 2,
    "5m": 3,
    "15m": 4,
    "30m": 5,
    "1h": 6,
    "2h": 7,
    "4h": 8,
    "1d": 9,
    "1w": 10,
}

TIMEFRAME_MINUTES: dict[str, int] = {
    "1m": 1, "3m": 3, "5m": 5, "15m": 15, "30m": 30,
    "1h": 60, "2h": 120, "4h": 240, "1d": 1440, "1w": 10080,
}


def can_invalidate_structure(candle_tf: str, structure_tf: str) -> bool:
    return TIMEFRAME_RANK.get(candle_tf, 0) >= TIMEFRAME_RANK.get(structure_tf, 0)


def get_rank(timeframe: str) -> int:
    return TIMEFRAME_RANK.get(timeframe, 0)


def get_minutes(timeframe: str) -> int:
    return TIMEFRAME_MINUTES.get(timeframe, 5)
