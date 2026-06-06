import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Query

from app.services.freqtrade_db import freqtrade_db
from app.schemas.api import OrderResponse, PositionResponse

router = APIRouter(prefix="/api", tags=["orders"])
logger = logging.getLogger(__name__)

_SYMBOLS = ["BTC/USDT", "ETH/USDT", "SOL/USDT", "BNB/USDT", "XRP/USDT"]


def _mock_orders(limit: int) -> list[dict]:
    orders = []
    source = freqtrade_db.source_status(simulated=True)
    for i in range(limit):
        side = "BUY" if i % 2 == 0 else "SELL"
        price = round(40000 + (i * 173.25) % 25000, 2)
        qty = round(0.01 + (i % 9) * 0.017, 3)
        profit = round(((-1) ** i) * (80 + i * 7.5), 2)
        orders.append({
            "id": i + 1,
            "strategy_id": (i % 4) + 1,
            "symbol": _SYMBOLS[i % len(_SYMBOLS)],
            "side": side,
            "order_type": "market",
            "quantity": qty,
            "price": price,
            "filled_price": round(price * (1.0005 if side == "BUY" else 0.9995), 2),
            "fee": round(price * 0.001, 2),
            "slippage": round(price * 0.0005, 2),
            "timestamp": (datetime.now(timezone.utc) - timedelta(hours=i * 6)).isoformat(),
            "status": "filled",
            "profit": profit,
            "pnl_pct": round(profit / max(price * 0.01, 1) * 100, 2),
            "data_source": source,
        })
    return sorted(orders, key=lambda x: x["timestamp"], reverse=True)


def _mock_positions() -> list[dict]:
    source = freqtrade_db.source_status(simulated=True)
    return [
        {"id": 1, "user_id": 1, "strategy_id": 1, "symbol": "BTC/USDT", "side": "long", "quantity": 0.5, "avg_price": 62350, "unrealized_pnl": 1250, "stop_loss_price": 60000, "status": "open", "opened_at": (datetime.now(timezone.utc) - timedelta(days=2)).isoformat(), "data_source": source},
        {"id": 2, "user_id": 1, "strategy_id": 2, "symbol": "ETH/USDT", "side": "long", "quantity": 5, "avg_price": 3420, "unrealized_pnl": -180, "stop_loss_price": 3200, "status": "open", "opened_at": (datetime.now(timezone.utc) - timedelta(days=1)).isoformat(), "data_source": source},
        {"id": 3, "user_id": 1, "strategy_id": 3, "symbol": "SOL/USDT", "side": "short", "quantity": 20, "avg_price": 178, "unrealized_pnl": 340, "stop_loss_price": 190, "status": "open", "opened_at": (datetime.now(timezone.utc) - timedelta(days=3)).isoformat(), "data_source": source},
    ]


@router.get("/orders", response_model=list[OrderResponse])
def list_orders(limit: int = Query(default=50, ge=1, le=500)):
    try:
        trades = freqtrade_db.get_trades(limit=limit)
    except Exception as e:
        logger.warning(f"[orders] freqtrade_db.get_trades failed, mock fallback: {e}")
        trades = None

    if not trades:
        if trades is None:
            logger.warning("[orders] freqtrade_db returned no data, using mock")
        trades = _mock_orders(limit)
    else:
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
        logger.warning(f"[positions] freqtrade_db.get_open_trades failed, mock fallback: {e}")
        trades = None

    if not trades:
        if trades is None:
            logger.warning("[positions] freqtrade_db returned no data, using mock")
        trades = _mock_positions()
    else:
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
