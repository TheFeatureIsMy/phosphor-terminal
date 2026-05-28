from datetime import datetime, timedelta, timezone
from fastapi import APIRouter

from app.services.freqtrade_client import freqtrade_client
from app.schemas.api import (
    BacktestRequest, BacktestResponse, BacktestResultResponse,
    BacktestMetricsResponse,
)

router = APIRouter(prefix="/api/backtest", tags=["backtest"])


def _generate_simulated_backtest(request: BacktestRequest) -> dict:
    """Generate deterministic simulated backtest result when Freqtrade is unavailable."""
    start = datetime.strptime(request.start_date, "%Y-%m-%d")
    end = datetime.strptime(request.end_date, "%Y-%m-%d")
    days = max((end - start).days, 1)
    data_source = {
        "source": "simulated",
        "simulated": True,
        "available": False,
        "detail": "Freqtrade backtest API is unavailable; deterministic simulated result is shown.",
    }

    equity_curve = []
    value = request.initial_capital
    peak = value
    current = start
    day_index = 0
    while current <= end:
        cycle = ((day_index % 11) - 4) / 1000
        change = value * (0.0015 + cycle)
        value += change
        peak = max(peak, value)
        drawdown = ((value - peak) / peak * 100) if peak > 0 else 0
        equity_curve.append({
            "date": current.strftime("%Y-%m-%d"),
            "value": round(value, 2),
            "drawdown": round(drawdown, 2),
            "data_source": data_source,
        })
        current += timedelta(days=1)
        day_index += 1

    trades = []
    symbols = request.symbols or ["BTC/USDT"]
    trade_count = min(max(days * 2, 12), 60)
    for i in range(trade_count):
        side = "BUY" if i % 2 == 0 else "SELL"
        price = 25000 + ((i * 719) % 43000)
        qty = 0.01 + (i % 8) * 0.006
        profit = ((i % 5) - 1.7) * 42
        trades.append({
            "id": i + 1,
            "strategy_id": request.strategy_id,
            "symbol": symbols[i % len(symbols)],
            "side": side,
            "order_type": "market",
            "quantity": round(qty, 6),
            "price": round(price, 2),
            "filled_price": round(price * (1.0004 if side == "BUY" else 0.9996), 2),
            "fee": round(abs(price * qty * 0.001), 2),
            "slippage": round(price * 0.0004, 4),
            "timestamp": (start + timedelta(days=i % days)).isoformat(),
            "status": "filled",
            "profit": round(profit, 2),
            "pnl_pct": round(profit / (price * qty) * 100, 2),
            "data_source": data_source,
        })

    total_trades = len(trades)
    wins = sum(1 for t in trades if (t.get("profit") or 0) > 0)
    total_profit = sum(t.get("profit") or 0 for t in trades)
    win_rate = (wins / total_trades * 100) if total_trades > 0 else 0
    total_return = (total_profit / request.initial_capital) * 100

    metrics = BacktestMetricsResponse(
        total_return=round(total_return, 2),
        sharpe_ratio=1.12,
        max_drawdown=round(abs(min(point["drawdown"] for point in equity_curve)), 2),
        win_rate=round(win_rate, 1),
        profit_factor=1.36,
        total_trades=total_trades,
        avg_trade_duration="8h 00m",
        best_trade=round(max(t.get("profit") or 0 for t in trades), 2),
        worst_trade=round(min(t.get("profit") or 0 for t in trades), 2),
    )

    return {
        "equity_curve": equity_curve,
        "trades": trades,
        "metrics": metrics,
        "sharpe_ratio": metrics.sharpe_ratio,
        "max_drawdown": metrics.max_drawdown,
        "win_rate": metrics.win_rate,
        "total_return": metrics.total_return,
        "data_source": data_source,
    }


@router.post("", response_model=BacktestResponse)
async def run_backtest(request: BacktestRequest):
    # Try Freqtrade first
    ft_result = await freqtrade_client.run_backtest({
        "strategy": request.strategy_id,
        "timerange": f"{request.start_date.replace('-', '')}-{request.end_date.replace('-', '')}",
        "stake_amount": request.initial_capital,
    })

    if "error" not in ft_result:
        return BacktestResponse(
            id=1,
            strategy_id=request.strategy_id,
            config=request.model_dump(),
            result=BacktestResultResponse(
                equity_curve=ft_result.get("equity_curve", []),
                trades=ft_result.get("trades", []),
                metrics=BacktestMetricsResponse(
                    total_return=ft_result.get("total_return", 0),
                    sharpe_ratio=ft_result.get("sharpe_ratio", 0),
                    max_drawdown=ft_result.get("max_drawdown", 0),
                    win_rate=ft_result.get("win_rate", 0),
                    profit_factor=ft_result.get("profit_factor", 0),
                    total_trades=ft_result.get("total_trades", 0),
                    avg_trade_duration=ft_result.get("avg_trade_duration", "0h 0m"),
                    best_trade=ft_result.get("best_trade", 0),
                    worst_trade=ft_result.get("worst_trade", 0),
                ),
            ),
            sharpe_ratio=ft_result.get("sharpe_ratio", 0),
            max_drawdown=ft_result.get("max_drawdown", 0),
            win_rate=ft_result.get("win_rate", 0),
            total_return=ft_result.get("total_return", 0),
            passed=ft_result.get("sharpe_ratio", 0) > 1.0,
            created_at=datetime.now(timezone.utc),
            data_source={
                "source": "freqtrade",
                "simulated": False,
                "available": True,
                "detail": None,
            },
        )

    simulated = _generate_simulated_backtest(request)
    return BacktestResponse(
        id=1,
        strategy_id=request.strategy_id,
        config=request.model_dump(),
        result=BacktestResultResponse(
            equity_curve=simulated["equity_curve"],
            trades=simulated["trades"],
            metrics=simulated["metrics"],
        ),
        sharpe_ratio=simulated["sharpe_ratio"],
        max_drawdown=simulated["max_drawdown"],
        win_rate=simulated["win_rate"],
        total_return=simulated["total_return"],
        passed=simulated["sharpe_ratio"] > 1.0,
        created_at=datetime.now(timezone.utc),
        data_source=simulated["data_source"],
    )


@router.get("/{backtest_id}", response_model=BacktestResponse)
async def get_backtest(backtest_id: int):
    simulated = _generate_simulated_backtest(BacktestRequest(strategy_id=1))
    return BacktestResponse(
        id=backtest_id,
        strategy_id=1,
        config={"start_date": "2025-01-01", "end_date": "2025-12-31", "initial_capital": 10000},
        result=BacktestResultResponse(
            equity_curve=simulated["equity_curve"],
            trades=simulated["trades"],
            metrics=simulated["metrics"],
        ),
        sharpe_ratio=simulated["sharpe_ratio"],
        max_drawdown=simulated["max_drawdown"],
        win_rate=simulated["win_rate"],
        total_return=simulated["total_return"],
        passed=simulated["sharpe_ratio"] > 1.0,
        created_at=datetime.now(timezone.utc),
        data_source=simulated["data_source"],
    )
