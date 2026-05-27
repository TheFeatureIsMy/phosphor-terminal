import random
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Query

from app.services.freqtrade_db import freqtrade_db
from app.schemas.api import OrderResponse, PositionResponse

router = APIRouter(prefix="/api", tags=["orders"])

_SYMBOLS = ["BTC/USDT", "ETH/USDT", "SOL/USDT", "BNB/USDT", "XRP/USDT"]


def _mock_orders(limit: int) -> list[dict]:
    orders = []
    for i in range(limit):
        side = random.choice(["BUY", "SELL"])
        price = round(random.uniform(100, 70000), 2)
        qty = round(random.uniform(0.001, 2), 3)
        profit = round(random.uniform(-500, 800), 2)
        orders.append({
            "id": i + 1,
            "strategy_id": random.randint(1, 4),
            "symbol": random.choice(_SYMBOLS),
            "side": side,
            "order_type": "market",
            "quantity": qty,
            "price": price,
            "filled_price": round(price * random.uniform(0.998, 1.002), 2),
            "fee": round(price * 0.001, 2),
            "slippage": round(random.uniform(0, price * 0.002), 2),
            "timestamp": (datetime.now(timezone.utc) - timedelta(days=random.randint(0, 30))).isoformat(),
            "status": random.choice(["filled", "filled", "filled", "cancelled", "failed"]),
            "profit": profit,
            "pnl_pct": round(profit / max(price * 0.01, 1) * 100, 2),
        })
    return sorted(orders, key=lambda x: x["timestamp"], reverse=True)


def _mock_positions() -> list[dict]:
    return [
        {"id": 1, "user_id": 1, "strategy_id": 1, "symbol": "BTC/USDT", "side": "long", "quantity": 0.5, "avg_price": 62350, "unrealized_pnl": 1250, "stop_loss_price": 60000, "status": "open", "opened_at": (datetime.now(timezone.utc) - timedelta(days=2)).isoformat()},
        {"id": 2, "user_id": 1, "strategy_id": 2, "symbol": "ETH/USDT", "side": "long", "quantity": 5, "avg_price": 3420, "unrealized_pnl": -180, "stop_loss_price": 3200, "status": "open", "opened_at": (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()},
        {"id": 3, "user_id": 1, "strategy_id": 3, "symbol": "SOL/USDT", "side": "short", "quantity": 20, "avg_price": 178, "unrealized_pnl": 340, "stop_loss_price": 190, "status": "open", "opened_at": (datetime.now(timezone.utc) - timedelta(days=3)).isoformat()},
    ]


@router.get("/orders", response_model=list[OrderResponse])
def list_orders(limit: int = Query(default=50, ge=1, le=500)):
    trades = freqtrade_db.get_trades(limit=limit)
    if not trades:
        trades = _mock_orders(limit)
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
        ))
    return result


@router.get("/positions", response_model=list[PositionResponse])
def list_positions():
    trades = freqtrade_db.get_open_trades()
    if not trades:
        trades = _mock_positions()
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
        ))
    return result
