"""In-memory cache of latest ticker prices per symbol."""
from __future__ import annotations

import time
from typing import Any


class TickerCache:
    """Singleton. set/get latest ticker per symbol; entries expire after ttl_s."""

    def __init__(self, ttl_s: float = 60.0) -> None:
        self._data: dict[str, tuple[float, dict[str, Any]]] = {}
        self.ttl_s = ttl_s

    def set(self, symbol: str, ticker: dict[str, Any]) -> None:
        self._data[symbol] = (time.time(), ticker)

    def get(self, symbol: str) -> dict[str, Any] | None:
        if symbol not in self._data:
            return None
        ts, ticker = self._data[symbol]
        if time.time() - ts > self.ttl_s:
            del self._data[symbol]
            return None
        return ticker

    def all(self) -> dict[str, dict[str, Any]]:
        return {sym: t for sym, (ts, t) in self._data.items() if time.time() - ts <= self.ttl_s}


# Process-wide singleton
ticker_cache = TickerCache()
