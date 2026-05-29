"""Market data service using CCXT for real-time data from Binance public API.

No API key required. Uses SQLite cache to avoid rate limits on repeated requests.
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np


class MarketDataService:
    """Real-time + cached market data from Binance public API."""

    def __init__(self, db_path: str = "data/market_data.db") -> None:
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._exchange = None
        self._init_db()

    def _get_exchange(self):
        if self._exchange is None:
            try:
                import ccxt
                self._exchange = ccxt.binance({"enableRateLimit": True})
            except ImportError:
                return None
        return self._exchange

    def _init_db(self) -> None:
        with sqlite3.connect(str(self.db_path)) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS ohlcv_cache (
                    symbol TEXT NOT NULL,
                    timeframe TEXT NOT NULL,
                    timestamp INTEGER NOT NULL,
                    open REAL,
                    high REAL,
                    low REAL,
                    close REAL,
                    volume REAL,
                    fetched_at TEXT NOT NULL,
                    PRIMARY KEY (symbol, timeframe, timestamp)
                )
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_ohlcv_symbol_tf
                ON ohlcv_cache(symbol, timeframe, timestamp)
            """)
            conn.commit()

    @property
    def available(self) -> bool:
        try:
            import ccxt  # noqa: F401
            return True
        except ImportError:
            return False

    async def get_recent_prices(self, symbol: str, limit: int = 100) -> list[float]:
        """Get recent close prices. Try cache first, then fetch from exchange."""
        import asyncio

        cached = self._get_cached_prices(symbol, "1h", limit)
        if cached and len(cached) >= limit:
            return cached

        exchange = self._get_exchange()
        if exchange is None:
            return cached or []

        try:
            ohlcv = await asyncio.to_thread(
                exchange.fetch_ohlcv, symbol, "1h", None, limit
            )
            if ohlcv:
                self._cache_ohlcv(symbol, "1h", ohlcv)
                return [float(candle[4]) for candle in ohlcv]
        except Exception:
            pass

        return cached or []

    async def get_ohlcv(
        self,
        symbol: str,
        timeframe: str = "1d",
        limit: int = 100,
    ) -> list[dict[str, Any]]:
        """Get full OHLCV data. Returns list of dicts with open/high/low/close/volume."""
        import asyncio

        cached = self._get_cached_ohlcv(symbol, timeframe, limit)
        if cached and len(cached) >= limit:
            return cached

        exchange = self._get_exchange()
        if exchange is None:
            return cached or []

        try:
            raw = await asyncio.to_thread(
                exchange.fetch_ohlcv, symbol, timeframe, None, limit
            )
            if raw:
                self._cache_ohlcv(symbol, timeframe, raw)
                return [
                    {
                        "timestamp": candle[0],
                        "open": float(candle[1]),
                        "high": float(candle[2]),
                        "low": float(candle[3]),
                        "close": float(candle[4]),
                        "volume": float(candle[5]),
                    }
                    for candle in raw
                ]
        except Exception:
            pass

        return cached or []

    def _get_cached_prices(self, symbol: str, timeframe: str, limit: int) -> list[float]:
        with sqlite3.connect(str(self.db_path)) as conn:
            rows = conn.execute(
                "SELECT close FROM ohlcv_cache WHERE symbol=? AND timeframe=? ORDER BY timestamp DESC LIMIT ?",
                (symbol, timeframe, limit),
            ).fetchall()
        return [float(r[0]) for r in reversed(rows)] if rows else []

    def _get_cached_ohlcv(self, symbol: str, timeframe: str, limit: int) -> list[dict]:
        with sqlite3.connect(str(self.db_path)) as conn:
            rows = conn.execute(
                "SELECT timestamp, open, high, low, close, volume FROM ohlcv_cache WHERE symbol=? AND timeframe=? ORDER BY timestamp DESC LIMIT ?",
                (symbol, timeframe, limit),
            ).fetchall()
        if not rows:
            return []
        return [
            {"timestamp": r[0], "open": float(r[1]), "high": float(r[2]),
             "low": float(r[3]), "close": float(r[4]), "volume": float(r[5])}
            for r in reversed(rows)
        ]

    def _cache_ohlcv(self, symbol: str, timeframe: str, ohlcv: list) -> None:
        now = datetime.now(timezone.utc).isoformat()
        with sqlite3.connect(str(self.db_path)) as conn:
            conn.executemany(
                "INSERT OR REPLACE INTO ohlcv_cache (symbol, timeframe, timestamp, open, high, low, close, volume, fetched_at) VALUES (?,?,?,?,?,?,?,?,?)",
                [(symbol, timeframe, c[0], c[1], c[2], c[3], c[4], c[5], now) for c in ohlcv],
            )
            conn.commit()


# Module-level singleton
market_data_service = MarketDataService()
