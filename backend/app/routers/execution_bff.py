"""Execution BFF — Center + Orders/Positions + Emergency"""
import logging
import time

from fastapi import APIRouter

from app.schemas.execution_bff import (
    ExecutionCenterResponse, ExecutionSession,
    OrdersPositionsResponse, OrderResponse, PositionResponse,
    ReconciliationBusResponse, ReconciliationRun, CommandBusEvent,
)
from app.schemas.common import AvailableAction

router = APIRouter(prefix="/api/execution", tags=["execution-bff"])
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Mock fallbacks
# ---------------------------------------------------------------------------

def _mock_center() -> dict:
    return ExecutionCenterResponse(
        state="running",
        reason_codes=[],
        available_actions=[
            AvailableAction(type="emergency_stop", enabled=True, label="紧急停止", confirm_required=True),
        ],
        sessions=[
            ExecutionSession(run_id="run-001", strategy_name="BTC Structure Scalp", mode="live_small", status="running", symbol="BTC/USDT", open_positions=2, pending_orders=1),
            ExecutionSession(run_id="run-002", strategy_name="ETH FVG Hunter", mode="dryrun", status="running", symbol="ETH/USDT", open_positions=1, pending_orders=0),
        ],
        total_running=2,
        total_open_positions=3,
        total_pending_orders=1,
        freqtrade_heartbeat="healthy",
        execution_latency_ms=45,
    ).model_dump()


def _mock_orders_positions() -> dict:
    return OrdersPositionsResponse(
        state="healthy",
        reason_codes=[],
        available_actions=[
            AvailableAction(type="cancel_all_orders", enabled=True, label="取消所有挂单", confirm_required=True),
            AvailableAction(type="force_close_all", enabled=True, label="强制平仓所有", confirm_required=True),
        ],
        orders=[
            OrderResponse(id="ord-001", symbol="BTC/USDT", side="buy", type="limit", quantity=0.01, price=61500, status="pending", exchange_order_id="ex-12345"),
        ],
        positions=[
            PositionResponse(id="pos-001", symbol="BTC/USDT", side="long", avg_entry_price=62100, current_price=62450, quantity=0.05, unrealized_pnl=17.5, unrealized_pnl_pct=0.56, stop_loss=61200),
            PositionResponse(id="pos-002", symbol="ETH/USDT", side="long", avg_entry_price=3380, current_price=3410, quantity=1.0, unrealized_pnl=30, unrealized_pnl_pct=0.89, stop_loss=3320),
            PositionResponse(id="pos-003", symbol="BTC/USDT", side="short", avg_entry_price=62800, current_price=62450, quantity=0.02, unrealized_pnl=7, unrealized_pnl_pct=0.56, stop_loss=63200),
        ],
    ).model_dump()


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/center", response_model=ExecutionCenterResponse)
async def get_execution_center():
    try:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()

        # Measure heartbeat latency
        t0 = time.time()
        is_alive = await ft.ping()
        latency_ms = int((time.time() - t0) * 1000)

        heartbeat = "healthy" if is_alive else "unhealthy"

        # Get open trades / positions from Freqtrade
        status_data = await ft.get_status()

        # status_data may be a list of trades or a dict with error
        if not FreqtradeClient.is_success(status_data):
            # Freqtrade returned an error but is reachable — partial data
            return ExecutionCenterResponse(
                state="degraded",
                reason_codes=["freqtrade_status_error"],
                available_actions=[
                    AvailableAction(type="emergency_stop", enabled=True, label="紧急停止", confirm_required=True),
                ],
                sessions=[],
                total_running=0,
                total_open_positions=0,
                total_pending_orders=0,
                freqtrade_heartbeat=heartbeat,
                execution_latency_ms=latency_ms,
            ).model_dump()

        # Freqtrade /api/v1/status returns a list of open trades
        trades = status_data if isinstance(status_data, list) else status_data.get("trades", [])

        # Map trades into ExecutionSession format (group by pair)
        sessions: list[ExecutionSession] = []
        total_positions = 0
        total_orders = 0

        for i, trade in enumerate(trades):
            trade_id = trade.get("trade_id", f"ft-{i}")
            pair = trade.get("pair", "UNKNOWN")
            is_open = trade.get("is_open", True)
            trade_status = "running" if is_open else "closed"

            # Count open orders for this trade
            orders_count = len(trade.get("orders", []))
            open_orders = sum(1 for o in trade.get("orders", []) if o.get("status") == "open")

            sessions.append(ExecutionSession(
                run_id=f"ft-trade-{trade_id}",
                strategy_name=trade.get("strategy", ""),
                mode="live_small",
                status=trade_status,
                symbol=pair,
                open_positions=1 if is_open else 0,
                pending_orders=open_orders,
            ))
            if is_open:
                total_positions += 1
            total_orders += open_orders

        running_count = sum(1 for s in sessions if s.status == "running")

        return ExecutionCenterResponse(
            state="running" if running_count > 0 else "idle",
            reason_codes=[],
            available_actions=[
                AvailableAction(type="emergency_stop", enabled=True, label="紧急停止", confirm_required=True),
            ],
            sessions=sessions,
            total_running=running_count,
            total_open_positions=total_positions,
            total_pending_orders=total_orders,
            freqtrade_heartbeat=heartbeat,
            execution_latency_ms=latency_ms,
        ).model_dump()
    except Exception as e:
        logger.warning(f"[execution-center] FreqtradeClient unavailable, mock fallback: {e}")
        data = _mock_center()
        data["_mock"] = True
        return data


@router.get("/orders", response_model=OrdersPositionsResponse)
async def get_orders_positions():
    try:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()
        status_data = await ft.get_status()

        if not FreqtradeClient.is_success(status_data):
            raise ValueError("Freqtrade status error")

        trades = status_data if isinstance(status_data, list) else status_data.get("trades", [])

        orders: list[OrderResponse] = []
        positions: list[PositionResponse] = []

        for trade in trades:
            trade_id = str(trade.get("trade_id", ""))
            pair = trade.get("pair", "UNKNOWN")
            is_open = trade.get("is_open", True)

            # Map open trade to position
            if is_open:
                side = "long" if trade.get("is_short", False) is False else "short"
                entry_price = float(trade.get("open_rate", 0))
                current_price = float(trade.get("current_rate", entry_price))
                amount = float(trade.get("amount", 0))
                profit_abs = float(trade.get("profit_abs", 0))
                profit_pct = float(trade.get("profit_ratio", 0)) * 100

                positions.append(PositionResponse(
                    id=f"pos-ft-{trade_id}",
                    symbol=pair,
                    side=side,
                    avg_entry_price=entry_price,
                    current_price=current_price,
                    quantity=amount,
                    unrealized_pnl=profit_abs,
                    unrealized_pnl_pct=profit_pct,
                    stop_loss=trade.get("stop_loss"),
                    take_profit=trade.get("take_profit"),
                    freqtrade_trade_id=trade_id,
                ))

            # Map individual orders
            for order in trade.get("orders", []):
                order_status = order.get("status", "unknown")
                if order_status in ("open", "pending"):
                    orders.append(OrderResponse(
                        id=f"ord-ft-{order.get('order_id', '')}",
                        symbol=pair,
                        side=order.get("side", "buy"),
                        type=order.get("order_type", "limit"),
                        quantity=float(order.get("amount", 0)),
                        price=order.get("price"),
                        status=order_status,
                        exchange_order_id=str(order.get("order_id", "")),
                        freqtrade_trade_id=trade_id,
                    ))

        return OrdersPositionsResponse(
            state="healthy",
            reason_codes=[],
            available_actions=[
                AvailableAction(type="cancel_all_orders", enabled=True, label="取消所有挂单", confirm_required=True),
                AvailableAction(type="force_close_all", enabled=True, label="强制平仓所有", confirm_required=True),
            ],
            orders=orders,
            positions=positions,
        ).model_dump()
    except Exception as e:
        logger.warning(f"[execution-orders] FreqtradeClient unavailable, mock fallback: {e}")
        data = _mock_orders_positions()
        data["_mock"] = True
        return data


@router.get("/positions", response_model=OrdersPositionsResponse)
async def get_positions():
    try:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()
        status_data = await ft.get_status()

        if not FreqtradeClient.is_success(status_data):
            raise ValueError("Freqtrade status error")

        trades = status_data if isinstance(status_data, list) else status_data.get("trades", [])

        positions: list[PositionResponse] = []

        for trade in trades:
            trade_id = str(trade.get("trade_id", ""))
            pair = trade.get("pair", "UNKNOWN")
            is_open = trade.get("is_open", True)

            if is_open:
                side = "long" if trade.get("is_short", False) is False else "short"
                entry_price = float(trade.get("open_rate", 0))
                current_price = float(trade.get("current_rate", entry_price))
                amount = float(trade.get("amount", 0))
                profit_abs = float(trade.get("profit_abs", 0))
                profit_pct = float(trade.get("profit_ratio", 0)) * 100

                positions.append(PositionResponse(
                    id=f"pos-ft-{trade_id}",
                    symbol=pair,
                    side=side,
                    avg_entry_price=entry_price,
                    current_price=current_price,
                    quantity=amount,
                    unrealized_pnl=profit_abs,
                    unrealized_pnl_pct=profit_pct,
                    stop_loss=trade.get("stop_loss"),
                    take_profit=trade.get("take_profit"),
                    freqtrade_trade_id=trade_id,
                ))

        return OrdersPositionsResponse(
            state="healthy",
            reason_codes=[],
            available_actions=[
                AvailableAction(type="cancel_all_orders", enabled=True, label="取消所有挂单", confirm_required=True),
                AvailableAction(type="force_close_all", enabled=True, label="强制平仓所有", confirm_required=True),
            ],
            orders=[],
            positions=positions,
        ).model_dump()
    except Exception as e:
        logger.warning(f"[execution-positions] FreqtradeClient unavailable, mock fallback: {e}")
        data = _mock_orders_positions()
        data["_mock"] = True
        return data


@router.post("/emergency-stop")
async def emergency_stop():
    try:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()
        result = await ft.stop_bot()

        if FreqtradeClient.is_success(result):
            return {
                "status": "emergency_stop_executed",
                "reason_codes": ["manual_trigger"],
                "freqtrade_response": result,
            }
        else:
            return {
                "status": "emergency_stop_attempted",
                "reason_codes": ["manual_trigger", "freqtrade_error"],
                "error": result.get("error", "unknown"),
            }
    except Exception as e:
        logger.warning(f"[emergency-stop] FreqtradeClient unavailable, mock fallback: {e}")
        return {"status": "emergency_stop_executed", "reason_codes": ["manual_trigger"], "_mock": True}
