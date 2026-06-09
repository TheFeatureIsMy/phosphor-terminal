from __future__ import annotations

import logging
import uuid
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Optional

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


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


# ---------------------------------------------------------------------------
# DB persistence layer — FailureClusterRecord
# ---------------------------------------------------------------------------

def save_clusters(
    db: Session,
    clusters: list[FailureCluster],
    strategy_id: str | uuid.UUID | None = None,
) -> list:
    """Persist a batch of FailureCluster dataclass instances to
    ``failure_clusters`` table, returning the created ORM rows.

    Existing *active* rows for the same ``strategy_id`` are marked
    ``status='archived'`` before inserting the fresh batch, so the table
    always reflects the latest clustering run.
    """
    from app.domain.shadow_strategy import FailureClusterRecord

    _strategy_id = uuid.UUID(str(strategy_id)) if strategy_id else None

    # Archive previous active clusters for this strategy
    if _strategy_id:
        (
            db.query(FailureClusterRecord)
            .filter(
                FailureClusterRecord.strategy_id == _strategy_id,
                FailureClusterRecord.status == "active",
            )
            .update({"status": "archived"})
        )

    rows = []
    for cluster in clusters:
        row = FailureClusterRecord(
            strategy_id=_strategy_id,
            label=cluster.cluster_name,
            sample_size=cluster.trade_count,
            total_loss=cluster.total_loss,
            avg_loss=cluster.avg_loss_pct,
            common_features={
                "suggested_fix": cluster.suggested_fix,
            },
            representative_trade_ids=cluster.example_trade_ids,
            status="active",
        )
        db.add(row)
        rows.append(row)

    db.flush()
    logger.info(
        "Saved %d failure clusters for strategy=%s", len(rows), strategy_id,
    )
    return rows


def load_clusters(
    db: Session,
    strategy_id: str | uuid.UUID | None = None,
    status: str = "active",
) -> list:
    """Load FailureClusterRecord rows from DB, optionally filtered by
    strategy and status.  Returns ORM instances."""
    from app.domain.shadow_strategy import FailureClusterRecord

    q = db.query(FailureClusterRecord)
    if strategy_id:
        _strategy_id = uuid.UUID(str(strategy_id)) if not isinstance(strategy_id, uuid.UUID) else strategy_id
        q = q.filter(FailureClusterRecord.strategy_id == _strategy_id)
    q = q.filter(FailureClusterRecord.status == status)
    q = q.order_by(FailureClusterRecord.total_loss.asc())
    return q.all()
