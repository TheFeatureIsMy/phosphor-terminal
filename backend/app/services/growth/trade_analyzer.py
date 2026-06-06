"""Trade analyzer — computes TradeMetrics from ExecutionTrade rows."""
from __future__ import annotations

from app.domain.order import ExecutionTrade
from app.schemas.growth import TradeMetrics


def compute_metrics(trades: list[ExecutionTrade]) -> TradeMetrics:
    if not trades:
        return TradeMetrics()

    wins, losses, breakevens = 0, 0, 0
    total_pnl = 0.0
    profits: list[float] = []
    loss_amts: list[float] = []
    best = float("-inf")
    worst = float("inf")
    hold_hours: list[float] = []
    symbols: set[str] = set()

    for t in trades:
        pct = float(t.profit_pct or 0)
        pnl = float(t.profit_abs or 0)
        total_pnl += pnl

        if pct > 0:
            wins += 1
            profits.append(pct)
        elif pct < 0:
            losses += 1
            loss_amts.append(pct)
        else:
            breakevens += 1

        best = max(best, pct)
        worst = min(worst, pct)
        symbols.add(t.symbol)

        if t.opened_at and t.closed_at:
            delta = (t.closed_at - t.opened_at).total_seconds() / 3600
            hold_hours.append(delta)

    n = len(trades)
    total_profit = sum(profits) if profits else 0.0
    total_loss = abs(sum(loss_amts)) if loss_amts else 0.0

    return TradeMetrics(
        total_trades=n,
        win_count=wins,
        loss_count=losses,
        breakeven_count=breakevens,
        win_rate=round(wins / n, 4) if n else 0.0,
        total_pnl=round(total_pnl, 6),
        avg_profit_pct=round(total_profit / len(profits), 4) if profits else 0.0,
        avg_loss_pct=round(sum(loss_amts) / len(loss_amts), 4) if loss_amts else 0.0,
        max_drawdown_pct=round(abs(worst), 4) if worst < 0 else 0.0,
        best_trade_pct=round(best, 4) if best != float("-inf") else 0.0,
        worst_trade_pct=round(worst, 4) if worst != float("inf") else 0.0,
        avg_hold_duration_hours=round(sum(hold_hours) / len(hold_hours), 2) if hold_hours else 0.0,
        profit_factor=round(total_profit / total_loss, 4) if total_loss > 0 else 0.0,
        symbols_traded=sorted(symbols),
    )
