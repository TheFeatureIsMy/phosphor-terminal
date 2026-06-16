"""CCXT Binance watch_ticker background stream. Updates TickerCache."""
from __future__ import annotations

import asyncio
import logging

logger = logging.getLogger(__name__)


async def run_binance_ticker_stream(symbols: list[str] | None = None) -> None:
    """Background task: subscribe to Binance public ticker stream."""
    if symbols is None:
        symbols = ["BTC/USDT"]
    from app.services.providers.realtime.ticker_cache import ticker_cache

    try:
        import ccxt.async_support as ccxt
    except ImportError:
        logger.warning("ccxt.async_support not available; ticker stream disabled")
        return

    exchange = ccxt.binance({"enableRateLimit": True})
    retries = 0
    try:
        while True:
            try:
                for symbol in symbols:
                    while True:
                        ticker = await exchange.watch_ticker(symbol)
                        ticker_cache.set(symbol, {
                            "last": ticker.get("last"),
                            "bid": ticker.get("bid"),
                            "ask": ticker.get("ask"),
                            "volume": ticker.get("baseVolume"),
                            "ts": ticker.get("timestamp"),
                        })
                        retries = 0
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                retries += 1
                if retries > 3:
                    logger.error("Ticker stream failed 3 times; giving up: %s", exc)
                    return
                backoff = 2 ** retries
                logger.warning("Ticker stream error (retry %d in %ds): %s", retries, backoff, exc)
                await asyncio.sleep(backoff)
    finally:
        await exchange.close()
