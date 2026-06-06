from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field


@dataclass
class FailureCluster:
    cluster_name: str
    trade_count: int
    total_loss: float
    avg_loss_pct: float
    example_trade_ids: list[str]
    suggested_fix: str


CLUSTER_SUGGESTIONS = {
    "entered_before_reclaim_confirmation": "Require confirmed_sweep state before entry — add reclaim confirmation filter",
    "stop_too_close_to_liquidity_pool": "Increase atr_buffer_coef in stop_policy (try 0.5 instead of 0.3)",
    "failed_due_to_news_shock": "Enable slow_track_ai_cache_required=True in runtime_mode",
    "failed_due_to_panic": "Add market_regime NOT IN ['panic'] to entry conditions",
    "failed_due_to_high_volatility": "Reduce position size during high_volatility regime",
    "ai_cache_expired_reduced_size": "Increase AI cache refresh frequency or TTL",
    "ai_cache_missing": "Ensure AI Slow Track is running before live trading",
    "snapshot_disconnect_emergency_close": "Check Redis/network reliability, increase max_snapshot_miss_ticks",
}


def cluster_failures(
    trades: list[dict],
    labels: dict[str, list[str]],
) -> list[FailureCluster]:
    clusters: dict[str, dict] = defaultdict(lambda: {
        "count": 0, "total_loss": 0.0, "losses": [], "ids": [],
    })

    for trade in trades:
        trade_id = trade.get("trade_id", "")
        profit = trade.get("profit_pct", 0.0)
        if profit >= 0:
            continue

        trade_labels = labels.get(trade_id, [])
        if not trade_labels:
            trade_labels = ["unclassified_loss"]

        primary = trade_labels[0]
        clusters[primary]["count"] += 1
        clusters[primary]["total_loss"] += profit
        clusters[primary]["losses"].append(profit)
        if len(clusters[primary]["ids"]) < 5:
            clusters[primary]["ids"].append(trade_id)

    result = []
    for name, data in clusters.items():
        avg_loss = data["total_loss"] / data["count"] if data["count"] > 0 else 0
        result.append(FailureCluster(
            cluster_name=name,
            trade_count=data["count"],
            total_loss=round(data["total_loss"], 4),
            avg_loss_pct=round(avg_loss, 4),
            example_trade_ids=data["ids"],
            suggested_fix=CLUSTER_SUGGESTIONS.get(name, "Review trade setup and market conditions"),
        ))

    result.sort(key=lambda c: c.total_loss)
    return result


def generate_optimization_suggestions(clusters: list[FailureCluster]) -> list[str]:
    return [c.suggested_fix for c in clusters if c.suggested_fix]
