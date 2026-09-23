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


# ---------------------------------------------------------------------------
# In-memory FailureClusteringService - async BFF fallback
# ---------------------------------------------------------------------------

class FailureClusteringService:
    """Failure clustering service — reads real ExecutionTrade data and runs clustering."""

    async def get_summary(self, strategy_run_id: Optional[str] = None) -> dict:
        from app.database import SessionLocal
        from app.domain.order import ExecutionTrade
        from sqlalchemy import select, and_

        db = SessionLocal()
        try:
            stmt = select(ExecutionTrade).where(
                ExecutionTrade.status == "closed",
                ExecutionTrade.profit_abs < 0,
            )
            if strategy_run_id:
                stmt = stmt.where(ExecutionTrade.strategy_run_id == uuid.UUID(strategy_run_id))
            stmt = stmt.order_by(ExecutionTrade.closed_at.desc()).limit(200)

            losing_trades = list(db.scalars(stmt).all())

            if not losing_trades:
                return {
                    "state": "healthy",
                    "reason_codes": [],
                    "available_actions": [],
                    "total_loss_trades": 0,
                    "total_loss_amount": 0.0,
                    "clusters": [],
                    "regime_matrix": [],
                    "common_reject_reasons": [],
                    "labels": [],
                }

            # Convert to dicts for clustering
            trade_dicts = []
            labels_map: dict[str, list[str]] = {}
            for t in losing_trades:
                tid = str(t.id)
                trade_dicts.append({
                    "trade_id": tid,
                    "profit_pct": float(t.profit_pct or 0),
                    "profit_abs": float(t.profit_abs or 0),
                    "symbol": t.symbol,
                    "duration_hours": (
                        (t.closed_at - t.opened_at).total_seconds() / 3600
                        if t.opened_at and t.closed_at else 0
                    ),
                })
                # Auto-label based on trade characteristics
                labels_map[tid] = self._auto_label(t)

            clusters = cluster_failures(trade_dicts, labels_map)
            total_loss = sum(float(t.profit_abs or 0) for t in losing_trades)

            return {
                "state": "healthy",
                "reason_codes": [],
                "available_actions": [
                    {"type": "generate_optimization", "enabled": True, "label": "Generate Optimization"},
                ],
                "total_loss_trades": len(losing_trades),
                "total_loss_amount": round(total_loss, 2),
                "clusters": [
                    {
                        "cluster_name": c.cluster_name,
                        "trade_count": c.trade_count,
                        "total_loss": c.total_loss,
                        "avg_loss_pct": c.avg_loss_pct,
                        "suggested_fix": c.suggested_fix,
                    }
                    for c in clusters
                ],
                "regime_matrix": [],
                "common_reject_reasons": [],
                "labels": list(set(l for ls in labels_map.values() for l in ls)),
            }
        except Exception as exc:
            logger.exception("Failure clustering failed: %s", exc)
            return {
                "state": "data_source_unavailable",
                "reason_codes": [str(exc)],
                "available_actions": [],
                "total_loss_trades": 0,
                "total_loss_amount": 0.0,
                "clusters": [],
                "regime_matrix": [],
                "common_reject_reasons": [],
                "labels": [],
            }
        finally:
            db.close()

    async def get_clusters(self, strategy_run_id: Optional[str] = None) -> dict:
        summary = await self.get_summary(strategy_run_id)
        return {
            "state": summary["state"],
            "reason_codes": summary["reason_codes"],
            "clusters": summary["clusters"],
        }

    async def get_labels(self, strategy_run_id: Optional[str] = None) -> dict:
        summary = await self.get_summary(strategy_run_id)
        return {
            "state": summary["state"],
            "reason_codes": summary["reason_codes"],
            "labels": summary["labels"],
        }

    async def get_regime_matrix(self) -> dict:
        return {
            "state": "healthy",
            "reason_codes": [],
            "regime_matrix": [],
        }

    @staticmethod
    def _auto_label(trade) -> list[str]:
        """Auto-label a losing trade based on its characteristics."""
        labels = []
        profit_pct = float(trade.profit_pct or 0)
        duration_hours = 0
        if trade.opened_at and trade.closed_at:
            duration_hours = (trade.closed_at - trade.opened_at).total_seconds() / 3600

        # Quick loss (< 30 min) suggests stop hit or volatility
        if duration_hours < 0.5 and profit_pct < -0.02:
            labels.append("stop_too_close_to_liquidity_pool")
        elif duration_hours < 0.1:
            labels.append("failed_due_to_high_volatility")

        # Large loss suggests news/panic
        if profit_pct < -0.05:
            labels.append("failed_due_to_news_shock")

        if not labels:
            labels.append("unclassified_loss")

        return labels
