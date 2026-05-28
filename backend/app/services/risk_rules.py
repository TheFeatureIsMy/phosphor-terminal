from __future__ import annotations

from typing import Any


def evaluate_risk_rules(payload: dict[str, Any]) -> list[dict[str, Any]]:
    """Evaluate deterministic PRD Phase 2 risk rules against current state."""
    events: list[dict[str, Any]] = []
    strategy_id = payload.get("strategy_id")
    market = payload.get("market", "crypto")
    symbol = payload.get("symbol") or "portfolio"

    pnl_pct = payload.get("position_pnl_pct")
    if pnl_pct is not None and pnl_pct <= -5:
        events.append(
            {
                "event_type": "stop_loss",
                "strategy_id": strategy_id,
                "market": market,
                "severity": "high" if pnl_pct <= -8 else "medium",
                "description": f"{symbol} position loss reached {pnl_pct:.2f}%, stop-loss threshold breached.",
                "action_taken": "block_new_entries_and_request_exit_review",
            }
        )

    take_profit_pct = payload.get("take_profit_pct")
    if take_profit_pct is not None and take_profit_pct >= 8:
        events.append(
            {
                "event_type": "take_profit",
                "strategy_id": strategy_id,
                "market": market,
                "severity": "low",
                "description": f"{symbol} unrealized profit reached {take_profit_pct:.2f}%, take-profit review triggered.",
                "action_taken": "suggest_partial_exit",
            }
        )

    drawdown_pct = payload.get("drawdown_pct")
    max_drawdown_pct = payload.get("max_drawdown_pct", 10)
    if drawdown_pct is not None and drawdown_pct >= max_drawdown_pct:
        events.append(
            {
                "event_type": "max_drawdown",
                "strategy_id": strategy_id,
                "market": market,
                "severity": "critical",
                "description": f"Portfolio drawdown reached {drawdown_pct:.2f}% over limit {max_drawdown_pct:.2f}%.",
                "action_taken": "pause_strategy_and_require_manual_review",
            }
        )

    for pair in payload.get("correlation_pairs", []):
        correlation = float(pair.get("correlation", 0))
        if correlation >= 0.9:
            events.append(
                {
                    "event_type": "correlation_warning",
                    "strategy_id": strategy_id,
                    "market": market,
                    "severity": "medium",
                    "description": f"{pair.get('symbol_a', 'A')} and {pair.get('symbol_b', 'B')} correlation is {correlation:.2f}.",
                    "action_taken": "suggest_rebalance_or_reduce_overlap",
                }
            )

    api_error = payload.get("api_error")
    if api_error:
        events.append(
            {
                "event_type": "api_error",
                "strategy_id": strategy_id,
                "market": market,
                "severity": "high",
                "description": str(api_error),
                "action_taken": "freeze_execution_until_connector_recovers",
            }
        )

    return events
