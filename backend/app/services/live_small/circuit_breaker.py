"""Circuit breaker — daily loss and consecutive loss detection.

Pure computation: takes trade data, returns whether to stop.
Does NOT trigger emergency stop — caller decides action.
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass
class TradeResult:
    profit_abs: float
    profit_pct: float
    is_win: bool


def check_circuit_breaker(
    trades_today: list[TradeResult],
    total_budget: float,
    max_daily_loss_pct: float = 0.03,
    max_consecutive_losses: int = 3,
    hard_stop_consecutive: int = 5,
) -> dict:
    daily_loss = sum(t.profit_abs for t in trades_today if t.profit_abs < 0)
    daily_loss_pct = abs(daily_loss) / total_budget if total_budget > 0 else 0.0

    consecutive = 0
    for t in reversed(trades_today):
        if not t.is_win:
            consecutive += 1
        else:
            break

    reasons: list[str] = []
    should_stop = False

    if daily_loss_pct >= max_daily_loss_pct:
        should_stop = True
        reasons.append(
            f"Daily loss {daily_loss_pct:.2%} >= limit {max_daily_loss_pct:.2%}"
        )

    if consecutive >= hard_stop_consecutive:
        should_stop = True
        reasons.append(
            f"Consecutive losses ({consecutive}) >= hard stop ({hard_stop_consecutive})"
        )

    should_cooldown = consecutive >= max_consecutive_losses and not should_stop
    if should_cooldown:
        reasons.append(
            f"Consecutive losses ({consecutive}) >= cooldown threshold ({max_consecutive_losses})"
        )

    return {
        "should_stop": should_stop,
        "should_cooldown": should_cooldown,
        "reasons": reasons,
        "daily_loss_pct": round(daily_loss_pct, 6),
        "consecutive_losses": consecutive,
        "total_trades_today": len(trades_today),
        "daily_pnl": round(sum(t.profit_abs for t in trades_today), 6),
    }
