from fastapi import APIRouter, HTTPException

from app.services.market_registry import market_registry


router = APIRouter(prefix="/api/markets", tags=["markets"])


@router.get("")
def list_markets():
    return {"items": market_registry.list()}


@router.get("/tape")
def market_tape():
    """Ticker tape — latest cached prices from the realtime ticker stream.

    Returns only symbols with fresh cache entries; empty when the stream
    is not running (honest empty state, no fabricated quotes).
    """
    from app.services.providers.realtime.ticker_cache import ticker_cache

    items = []
    for symbol, ticker in sorted(ticker_cache.all().items()):
        items.append({
            "symbol": symbol,
            "last": ticker.get("last"),
            "change_pct": ticker.get("change_pct"),
        })
    return {
        "state": "healthy" if items else "data_source_unavailable",
        "reason_codes": [] if items else ["ticker_stream_inactive"],
        "items": items,
    }


@router.get("/{market_id}")
def get_market(market_id: str):
    try:
        return market_registry.get(market_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
