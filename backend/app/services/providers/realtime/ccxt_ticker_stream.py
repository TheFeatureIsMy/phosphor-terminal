"""CCXT Binance ticker background poller. Updates TickerCache.

Uses REST polling instead of websocket (ccxt.pro) to avoid dependency issues.
"""
from __future__ import annotations

import asyncio
import logging
import os

logger = logging.getLogger(__name__)


def _proxy_from_env() -> str | None:
    """Read an outbound HTTPS proxy from the standard env vars, if set."""
    for key in ("HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy"):
        value = os.environ.get(key)
        if value:
            return value
    return None


async def run_binance_ticker_stream(symbols: list[str] | None = None) -> None:
    """Background task: poll Binance ticker via REST every 30 seconds."""
    if symbols is None:
        symbols = ["BTC/USDT"]
    from app.services.providers.realtime.ticker_cache import ticker_cache

    try:
        import ccxt.async_support as ccxt
    except ImportError:
        logger.warning("ccxt.async_support not available; ticker stream disabled")
        return

    config: dict = {"enableRateLimit": True}
    proxy = _proxy_from_env()
    if proxy:
        # ccxt.async_support uses aiohttp, which ignores the proxy env vars,
        # so pass it explicitly.
        config["httpsProxy"] = proxy
        logger.info("Binance ticker stream using proxy %s", proxy)
    exchange = ccxt.binance(config)
    try:
        while True:
            try:
                for symbol in symbols:
                    ticker = await exchange.fetch_ticker(symbol)
                    ticker_cache.set(symbol, {
                        "last": ticker.get("last"),
                        "bid": ticker.get("bid"),
                        "ask": ticker.get("ask"),
                        "volume": ticker.get("baseVolume"),
                        "ts": ticker.get("timestamp"),
                    })
                await asyncio.sleep(30)
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                logger.warning("Ticker poll error: %s", exc)
                await asyncio.sleep(30)
    finally:
        await exchange.close()
