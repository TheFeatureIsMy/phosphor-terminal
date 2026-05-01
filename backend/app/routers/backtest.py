import random
from datetime import datetime, timedelta
from fastapi import APIRouter

from app.services.freqtrade_client import freqtrade_client
from app.schemas.api import (
    BacktestRequest, BacktestResponse, BacktestResultResponse,
    BacktestMetricsResponse,
)

router = APIRouter(prefix="/api/backtest", tags=["backtest"])


def _generate_mock_backtest(request: BacktestRequest) -> dict:
    """Generate mock backtest result when Freqtrade is unavailable."""
    start = datetime.strptime(request.start_date, "%Y-%m-%d")
    end = datetime.strptime(request.end_date, "%Y-%m-%d")
    days = (end - start).days

    # Generate equity curve
    equity_curve = []
    value = request.initial_capital
    peak = value
    current = start
    while current <= end:
        change = value * random.uniform(-0.02, 0.03)
        value += change
        peak = max(peak, value)
        drawdown = ((value - peak) / peak * 100) if peak > 0 else 0
        equity_curve.append({
            "date": current.strftime("%Y-%m-%d"),
            "value": round(value, 2),
            "drawdown": round(drawdown, 2),
        })
        current += timedelta(days=1)

    # Generate mock trades
    trades = []
    symbols = request.symbols or ["BTC/USDT"]
    for i in range(random.randint(20, 60)):
        side = random.choice(["BUY", "SELL"])
        price = random.uniform(20000, 70000)
        qty = random.uniform(0.001, 0.1)
        profit = random.uniform(-500, 800)
        trades.append({
            "id": i + 1,
            "strategy_id": request.strategy_id,
            "symbol": random.choice(symbols),
            "side": side,
            "order_type": "market",
            "quantity": round(qty, 6),
            "price": round(price, 2),
            "filled_price": round(price * random.uniform(0.998, 1.002), 2),
            "fee": round(abs(price * qty * 0.001), 2),
            "slippage": round(random.uniform(-0.5, 0.5), 4),
            "timestamp": (start + timedelta(days=random.randint(0, days))).isoformat(),
            "status": "filled",
            "profit": round(profit, 2),
            "pnl_pct": round(profit / (price * qty) * 100, 2),
        })

    total_trades = len(trades)
    wins = sum(1 for t in trades if (t.get("profit") or 0) > 0)
    total_profit = sum(t.get("profit") or 0 for t in trades)
    win_rate = (wins / total_trades * 100) if total_trades > 0 else 0
    total_return = (total_profit / request.initial_capital) * 100

    metrics = BacktestMetricsResponse(
        total_return=round(total_return, 2),
        sharpe_ratio=round(random.uniform(0.5, 2.5), 2),
        max_drawdown=round(random.uniform(5, 25), 2),
        win_rate=round(win_rate, 1),
        profit_factor=round(random.uniform(1.0, 3.0), 2),
        total_trades=total_trades,
        avg_trade_duration=f"{random.randint(1, 48)}h {random.randint(0, 59)}m",
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
            created_at=datetime.utcnow(),
        )

    # Fallback to mock data
    mock = _generate_mock_backtest(request)
    return BacktestResponse(
        id=1,
        strategy_id=request.strategy_id,
        config=request.model_dump(),
        result=BacktestResultResponse(
            equity_curve=mock["equity_curve"],
            trades=mock["trades"],
            metrics=mock["metrics"],
        ),
        sharpe_ratio=mock["sharpe_ratio"],
        max_drawdown=mock["max_drawdown"],
        win_rate=mock["win_rate"],
        total_return=mock["total_return"],
        passed=mock["sharpe_ratio"] > 1.0,
        created_at=datetime.utcnow(),
    )


@router.get("/{backtest_id}", response_model=BacktestResponse)
async def get_backtest(backtest_id: int):
    mock = _generate_mock_backtest(BacktestRequest(strategy_id=1))
    return BacktestResponse(
        id=backtest_id,
        strategy_id=1,
        config={"start_date": "2025-01-01", "end_date": "2025-12-31", "initial_capital": 10000},
        result=BacktestResultResponse(
            equity_curve=mock["equity_curve"],
            trades=mock["trades"],
            metrics=mock["metrics"],
        ),
        sharpe_ratio=mock["sharpe_ratio"],
        max_drawdown=mock["max_drawdown"],
        win_rate=mock["win_rate"],
        total_return=mock["total_return"],
        passed=mock["sharpe_ratio"] > 1.0,
        created_at=datetime.utcnow(),
    )
