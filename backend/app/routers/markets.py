from fastapi import APIRouter, HTTPException

from app.services.market_registry import market_registry


router = APIRouter(prefix="/api/markets", tags=["markets"])


@router.get("")
def list_markets():
    return {"items": market_registry.list()}


@router.get("/{market_id}")
def get_market(market_id: str):
    try:
        return market_registry.get(market_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
