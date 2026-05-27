"""
Data processing utilities
"""
import statistics
from typing import Any


def calculate_returns(prices: list[float]) -> list[float]:
    """Calculate returns from price series"""
    if len(prices) < 2:
        return []
    return [(prices[i] - prices[i-1]) / prices[i-1] for i in range(1, len(prices))]


def calculate_sharpe_ratio(returns: list[float], risk_free_rate: float = 0.0) -> float:
    """Calculate Sharpe ratio"""
    if not returns:
        return 0.0
    mean_return = statistics.mean(returns)
    if len(returns) < 2:
        return 0.0
    std_return = statistics.stdev(returns)
    if std_return == 0:
        return 0.0
    return (mean_return - risk_free_rate) / std_return


def calculate_max_drawdown(equity_curve: list[float]) -> float:
    """Calculate maximum drawdown"""
    if not equity_curve:
        return 0.0
    peak = equity_curve[0]
    max_dd = 0.0
    for value in equity_curve:
        if value > peak:
            peak = value
        dd = (peak - value) / peak
        if dd > max_dd:
            max_dd = dd
    return max_dd


def calculate_win_rate(trades: list[dict[str, Any]]) -> float:
    """Calculate win rate from trades"""
    if not trades:
        return 0.0
    wins = sum(1 for t in trades if t.get('profit', 0) > 0)
    return wins / len(trades)


def calculate_profit_factor(trades: list[dict[str, Any]]) -> float:
    """Calculate profit factor"""
    if not trades:
        return 0.0
    gross_profit = sum(t.get('profit', 0) for t in trades if t.get('profit', 0) > 0)
    gross_loss = abs(sum(t.get('profit', 0) for t in trades if t.get('profit', 0) < 0))
    if gross_loss == 0:
        return float('inf') if gross_profit > 0 else 0.0
    return gross_profit / gross_loss
