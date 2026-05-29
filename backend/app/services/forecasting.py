from __future__ import annotations

from app.services.forecast_adapters import TimesFMAdapter, ChronosAdapter

_timesfm = TimesFMAdapter()
_chronos = ChronosAdapter()


async def generate_forecast(symbol: str, model: str, horizon: str) -> dict:
    days = 14 if horizon.endswith("14d") else 7
    adapter = _timesfm if model.lower() == "timesfm" else _chronos

    if not adapter.available:
        return {
            "status": "unavailable",
            "detail": f"{model} not installed",
            "points": [],
            "confidence": 0.0,
        }

    history = await _fetch_recent_prices(symbol, limit=100)
    if not history or len(history) < 4:
        return {
            "status": "error",
            "detail": f"Insufficient price data for {symbol}",
            "points": [],
            "confidence": 0.0,
        }

    result = await adapter.forecast(history, horizon=days)
    return result


async def _fetch_recent_prices(symbol: str, limit: int = 100) -> list[float]:
    """Fetch recent close prices. Try MarketDataService first, then FreqtradeDB, then empty."""
    from app.services.market_data import market_data_service

    # Try real market data first (CCXT Binance)
    if market_data_service.available:
        prices = await market_data_service.get_recent_prices(symbol, limit)
        if prices and len(prices) >= 10:
            return prices

    # Try FreqtradeDB as fallback
    try:
        from app.services.freqtrade_db import freqtrade_db

        if freqtrade_db.is_available():
            engine = freqtrade_db.engine
            if engine:
                rows = engine.execute(
                    "SELECT close FROM trades ORDER BY timestamp DESC LIMIT ?", (limit,)
                ).fetchall()
                if rows:
                    return [float(r[0]) for r in reversed(rows)]
    except Exception:
        pass

    return []
