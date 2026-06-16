import logging

from fastapi import APIRouter, HTTPException, Query

from app.services.freqtrade_db import freqtrade_db
from app.schemas.api import OrderResponse, PositionResponse

router = APIRouter(prefix="/api", tags=["orders"])
logger = logging.getLogger(__name__)

@router.get("/orders", response_model=list[OrderResponse])
def list_orders(limit: int = Query(default=50, ge=1, le=500)):
    try:
        trades = freqtrade_db.get_trades(limit=limit)
    except Exception as e:
        logger.exception("freqtrade_db.get_trades failed: %s", e)
        raise HTTPException(
            status_code=503,
            detail={
                "state": "data_source_unavailable",
                "reason_codes": ["data_source_unavailable", type(e).__name__],
            },
        )

    if not trades:
        return []

    source = freqtrade_db.source_status()
    for trade in trades:
        trade["data_source"] = source

    result = []
    for t in trades:
        result.append(OrderResponse(
            id=t["id"],
            strategy_id=t.get("strategy_id", 1),
            symbol=t["symbol"],
            side=t["side"],
            order_type=t.get("order_type", "market"),
            quantity=t.get("quantity", 0),
            price=t.get("price"),
            filled_price=t.get("filled_price"),
            fee=t.get("fee", 0) or 0,
            slippage=t.get("slippage", 0) or 0,
            timestamp=t["timestamp"],
            status=t["status"],
            profit=t.get("profit"),
            pnl_pct=t.get("pnl_pct"),
            data_source=t.get("data_source"),
        ))
    return result


@router.get("/positions", response_model=list[PositionResponse])
def list_positions():
    try:
        trades = freqtrade_db.get_open_trades()
    except Exception as e:
        logger.exception("freqtrade_db.get_open_trades failed: %s", e)
        raise HTTPException(
            status_code=503,
            detail={
                "state": "data_source_unavailable",
                "reason_codes": ["data_source_unavailable", type(e).__name__],
            },
        )

    if not trades:
        return []

    source = freqtrade_db.source_status()
    for trade in trades:
        trade["data_source"] = source

    result = []
    for t in trades:
        result.append(PositionResponse(
            id=t["id"],
            user_id=t.get("user_id", 1),
            strategy_id=t.get("strategy_id"),
            symbol=t["symbol"],
            side=t.get("side", "long"),
            quantity=t.get("quantity", 0),
            avg_price=t.get("avg_price", 0),
            unrealized_pnl=t.get("unrealized_pnl", 0) or 0,
            stop_loss_price=t.get("stop_loss_price"),
            take_profit_price=None,
            status=t.get("status", "open"),
            opened_at=t["opened_at"],
            closed_at=None,
            data_source=t.get("data_source"),
        ))
    return result
