"""Market data adapter — abstract interface + mock for testing."""
from __future__ import annotations

import math
import random
from abc import ABC, abstractmethod
from typing import Any


class MarketDataAdapter(ABC):
    @abstractmethod
    def get_ohlcv(self, symbol: str, timeframe: str, limit: int = 100) -> list[dict[str, Any]]:
        ...


class LiveMarketDataAdapter(MarketDataAdapter):
    """Real adapter backed by MarketDataService (CCXT + SQLite cache).

    Raises RuntimeError when no market data can be produced (ccxt missing,
    exchange unreachable and no cache); callers should translate that into
    a data_source_unavailable response rather than falling back to mocks.
    """

    def __init__(self, market_service: Any = None):
        self._market = market_service

    def _get_market(self):
        if self._market is None:
            from app.services.market_data import MarketDataService
            self._market = MarketDataService()
        return self._market

    def get_ohlcv(self, symbol: str, timeframe: str, limit: int = 100) -> list[dict[str, Any]]:
        import asyncio
        import concurrent.futures

        market = self._get_market()
        if not market.available:
            raise RuntimeError("ccxt not installed — live market data unavailable")

        def _fetch() -> list[dict[str, Any]]:
            return asyncio.run(market.get_ohlcv(symbol, timeframe=timeframe, limit=limit))

        try:
            asyncio.get_running_loop()
        except RuntimeError:
            candles = _fetch()
        else:
            # Called from within a running event loop — run in a worker thread
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
                candles = pool.submit(_fetch).result()

        if not candles:
            raise RuntimeError(f"no OHLCV data for {symbol} {timeframe}")
        return candles


class MockMarketDataAdapter(MarketDataAdapter):
    def __init__(self, seed: int = 42):
        self._rng = random.Random(seed)

    def get_ohlcv(self, symbol: str, timeframe: str, limit: int = 100) -> list[dict[str, Any]]:
        candles = []
        price = 100.0
        for i in range(limit):
            change = self._rng.gauss(0, 0.02)
            open_ = price
            close = price * (1 + change)
            high = max(open_, close) * (1 + abs(self._rng.gauss(0, 0.005)))
            low = min(open_, close) * (1 - abs(self._rng.gauss(0, 0.005)))
            volume = max(100, self._rng.gauss(10000, 3000))
            candles.append({
                "open": round(open_, 4),
                "high": round(high, 4),
                "low": round(low, 4),
                "close": round(close, 4),
                "volume": round(volume, 2),
            })
            price = close
        return candles


class SpikeMarketDataAdapter(MarketDataAdapter):
    """Generates data with deliberate manipulation patterns for testing."""

    def get_ohlcv(self, symbol: str, timeframe: str, limit: int = 100) -> list[dict[str, Any]]:
        candles = []
        price = 100.0
        for i in range(limit):
            if limit - 10 <= i <= limit - 6:
                open_ = price
                close = price * 1.05
                high = close * 1.02
                low = open_ * 0.99
                volume = 50000
            elif limit - 5 <= i <= limit - 1:
                open_ = price
                close = price * 0.95
                high = open_ * 1.01
                low = close * 0.98
                volume = 60000
            else:
                change = random.gauss(0, 0.005)
                open_ = price
                close = price * (1 + change)
                high = max(open_, close) * 1.002
                low = min(open_, close) * 0.998
                volume = 10000
            candles.append({
                "open": round(open_, 4),
                "high": round(high, 4),
                "low": round(low, 4),
                "close": round(close, 4),
                "volume": round(volume, 2),
            })
            price = close
        return candles
