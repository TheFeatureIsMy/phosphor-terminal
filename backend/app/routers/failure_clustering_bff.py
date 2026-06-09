"""Failure Clustering BFF — Clusters + Labels + Regime Matrix"""
import logging

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.failure_clustering_bff import (
    FailureClusteringResponse, FailureClusterResponse, RegimeFailureCell,
)
from app.schemas.common import AvailableAction

router = APIRouter(prefix="/api/growth", tags=["failure-clustering-bff"])
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Mock fallbacks (kept as-is for graceful degradation)
# ---------------------------------------------------------------------------

def _mock_clusters() -> list[FailureClusterResponse]:
    return [
        FailureClusterResponse(
            cluster_name="entered_before_reclaim_confirmation",
            label="过早入场",
            trade_count=12,
            total_loss=-840.50,
            avg_loss_pct=-1.2,
            example_trade_ids=["t-0041", "t-0055", "t-0078"],
            suggested_fix="等待结构回收确认后再入场，增加确认K线数量",
            severity="high",
        ),
        FailureClusterResponse(
            cluster_name="stop_too_close",
            label="止损过近",
            trade_count=8,
            total_loss=-520.30,
            avg_loss_pct=-0.9,
            example_trade_ids=["t-0032", "t-0048", "t-0091"],
            suggested_fix="使用ATR倍数或结构低点设定止损，避免噪音止损",
            severity="high",
        ),
        FailureClusterResponse(
            cluster_name="news_shock",
            label="新闻冲击",
            trade_count=5,
            total_loss=-1250.00,
            avg_loss_pct=-3.8,
            example_trade_ids=["t-0022", "t-0067"],
            suggested_fix="重大新闻事件前减仓或设置更宽止损",
            severity="critical",
        ),
        FailureClusterResponse(
            cluster_name="high_volatility",
            label="高波动环境",
            trade_count=7,
            total_loss=-430.20,
            avg_loss_pct=-1.0,
            example_trade_ids=["t-0015", "t-0039", "t-0082"],
            suggested_fix="波动率超过阈值时降低仓位或暂停交易",
            severity="medium",
        ),
        FailureClusterResponse(
            cluster_name="ai_cache_expired",
            label="AI缓存过期",
            trade_count=4,
            total_loss=-180.60,
            avg_loss_pct=-0.6,
            example_trade_ids=["t-0088", "t-0092"],
            suggested_fix="确保AI推理结果在有效期内使用，过期后重新请求",
            severity="low",
        ),
    ]


def _mock_regime_matrix() -> list[RegimeFailureCell]:
    return [
        RegimeFailureCell(regime="trend_up", failure_type="stop_too_close", count=5, total_loss=-320.00),
        RegimeFailureCell(regime="trend_up", failure_type="entered_before_reclaim_confirmation", count=3, total_loss=-210.50),
        RegimeFailureCell(regime="ranging", failure_type="entered_before_reclaim_confirmation", count=6, total_loss=-420.00),
        RegimeFailureCell(regime="ranging", failure_type="high_volatility", count=4, total_loss=-280.20),
        RegimeFailureCell(regime="trend_down", failure_type="news_shock", count=5, total_loss=-1250.00),
        RegimeFailureCell(regime="trend_down", failure_type="stop_too_close", count=3, total_loss=-200.30),
    ]


def _mock_labels() -> list[str]:
    return [
        "entered_before_reclaim_confirmation",
        "stop_too_close",
        "news_shock",
        "high_volatility",
        "ai_cache_expired",
        "fvg_already_filled",
        "counter_trend_entry",
        "overleveraged",
    ]


def _mock_failure_summary() -> dict:
    clusters = _mock_clusters()
    return FailureClusteringResponse(
        state="warning",
        reason_codes=["high_cluster_concentration", "news_shock_critical"],
        available_actions=[
            AvailableAction(type="refresh_clusters", enabled=True, label="刷新聚类分析"),
            AvailableAction(type="export_report", enabled=True, label="导出报告"),
            AvailableAction(type="apply_suggested_fixes", enabled=True, label="应用建议修复", confirm_required=True),
        ],
        total_loss_trades=36,
        total_loss_amount=-3221.60,
        clusters=clusters,
        regime_matrix=_mock_regime_matrix(),
        common_reject_reasons=[
            {"reason": "structure_not_confirmed", "count": 15},
            {"reason": "stop_inside_noise_range", "count": 8},
            {"reason": "news_event_active", "count": 5},
            {"reason": "volatility_too_high", "count": 7},
        ],
        labels=_mock_labels(),
    ).model_dump()


# ---------------------------------------------------------------------------
# Helpers — convert DB records to BFF response models
# ---------------------------------------------------------------------------

def _severity_from_loss(total_loss: float, count: int) -> str:
    """Derive severity from total loss magnitude."""
    if total_loss is None:
        return "medium"
    abs_loss = abs(float(total_loss))
    if abs_loss > 1000:
        return "critical"
    if abs_loss > 500:
        return "high"
    if abs_loss > 200:
        return "medium"
    return "low"


def _db_records_to_cluster_responses(records) -> list[FailureClusterResponse]:
    """Convert FailureClusterRecord ORM rows to BFF schema objects."""
    results = []
    for r in records:
        common = r.common_features or {}
        trade_ids = r.representative_trade_ids
        # representative_trade_ids may be stored as a list or a dict
        if isinstance(trade_ids, dict):
            trade_ids = list(trade_ids.values())
        elif not isinstance(trade_ids, list):
            trade_ids = []

        total = float(r.total_loss) if r.total_loss is not None else 0
        avg = float(r.avg_loss) if r.avg_loss is not None else 0

        results.append(FailureClusterResponse(
            cluster_name=r.label,
            label=r.label,
            trade_count=r.sample_size,
            total_loss=total,
            avg_loss_pct=avg,
            example_trade_ids=[str(tid) for tid in trade_ids],
            suggested_fix=common.get("suggested_fix", ""),
            severity=_severity_from_loss(total, r.sample_size),
        ))
    return results


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/failure-summary", response_model=FailureClusteringResponse)
async def get_failure_summary(
    strategy_id: str | None = Query(None),
    db: Session = Depends(get_db),
):
    # First, try loading from DB
    try:
        from app.services.failure_clustering import load_clusters

        records = load_clusters(db, strategy_id=strategy_id)
        if records:
            clusters = _db_records_to_cluster_responses(records)
            total_trades = sum(c.trade_count for c in clusters)
            total_loss = sum(c.total_loss for c in clusters)

            # Derive reason codes
            reason_codes = []
            for c in clusters:
                if c.severity == "critical":
                    reason_codes.append(f"{c.cluster_name}_critical")
            if any(c.trade_count > 10 for c in clusters):
                reason_codes.append("high_cluster_concentration")

            state = "critical" if any(c.severity == "critical" for c in clusters) else (
                "warning" if clusters else "healthy"
            )

            # Extract unique labels from DB clusters
            labels = list({c.cluster_name for c in clusters})

            return FailureClusteringResponse(
                state=state,
                reason_codes=reason_codes,
                available_actions=[
                    AvailableAction(type="refresh_clusters", enabled=True, label="刷新聚类分析"),
                    AvailableAction(type="export_report", enabled=True, label="导出报告"),
                    AvailableAction(type="apply_suggested_fixes", enabled=True, label="应用建议修复", confirm_required=True),
                ],
                total_loss_trades=total_trades,
                total_loss_amount=round(total_loss, 2),
                clusters=clusters,
                regime_matrix=[],  # regime matrix requires additional data
                common_reject_reasons=[],
                labels=labels,
            ).model_dump()
    except Exception as e:
        logger.warning("[failure-summary] DB load failed, trying service fallback: %s", e)

    # Second, try the in-memory FailureClusteringService
    try:
        from app.services.failure_clustering import FailureClusteringService
        svc = FailureClusteringService()
        return await svc.get_summary()
    except Exception as e:
        logger.warning(f"[failure-summary] FailureClusteringService unavailable, mock fallback: {e}")
        data = _mock_failure_summary()
        data["_mock"] = True
        return data


@router.get("/failure-clusters")
async def get_failure_clusters(
    strategy_id: str | None = Query(None),
    db: Session = Depends(get_db),
):
    # Try DB first
    try:
        from app.services.failure_clustering import load_clusters

        records = load_clusters(db, strategy_id=strategy_id)
        if records:
            clusters = _db_records_to_cluster_responses(records)
            return {
                "state": "healthy",
                "reason_codes": [],
                "clusters": [c.model_dump() for c in clusters],
            }
    except Exception as e:
        logger.warning("[failure-clusters] DB load failed: %s", e)

    # Fallback to service
    try:
        from app.services.failure_clustering import FailureClusteringService
        svc = FailureClusteringService()
        return await svc.get_clusters()
    except Exception as e:
        logger.warning(f"[failure-clusters] FailureClusteringService unavailable, mock fallback: {e}")
        return {
            "state": "healthy",
            "reason_codes": [],
            "clusters": [c.model_dump() for c in _mock_clusters()],
            "_mock": True,
        }


@router.get("/labels")
async def get_failure_labels(
    strategy_id: str | None = Query(None),
    db: Session = Depends(get_db),
):
    # Try DB first — collect unique labels from active clusters
    try:
        from app.services.failure_clustering import load_clusters

        records = load_clusters(db, strategy_id=strategy_id)
        if records:
            labels = sorted({r.label for r in records})
            return {
                "state": "healthy",
                "reason_codes": [],
                "labels": labels,
            }
    except Exception as e:
        logger.warning("[failure-labels] DB load failed: %s", e)

    try:
        from app.services.failure_clustering import FailureClusteringService
        svc = FailureClusteringService()
        return await svc.get_labels()
    except Exception as e:
        logger.warning(f"[failure-labels] FailureClusteringService unavailable, mock fallback: {e}")
        return {
            "state": "healthy",
            "reason_codes": [],
            "labels": _mock_labels(),
            "_mock": True,
        }


@router.get("/regime-matrix")
async def get_regime_matrix():
    try:
        from app.services.failure_clustering import FailureClusteringService
        svc = FailureClusteringService()
        return await svc.get_regime_matrix()
    except Exception as e:
        logger.warning(f"[regime-matrix] FailureClusteringService unavailable, mock fallback: {e}")
        return {
            "state": "healthy",
            "reason_codes": [],
            "regime_matrix": [c.model_dump() for c in _mock_regime_matrix()],
            "_mock": True,
        }


@router.post("/failure-clusters/save")
async def save_failure_clusters(
    body: dict,
    db: Session = Depends(get_db),
):
    """Run in-memory clustering on provided trades/labels, then persist
    the resulting clusters to the DB.

    Body:
        strategy_id: str (optional)
        trades: list[dict]  — each with trade_id, profit_pct
        labels: dict[str, list[str]] — trade_id -> label list
    """
    from app.services.failure_clustering import cluster_failures, save_clusters

    strategy_id = body.get("strategy_id")
    trades = body.get("trades", [])
    labels = body.get("labels", {})

    if not trades:
        return {"status": "no_trades", "clusters_saved": 0}

    clusters = cluster_failures(trades, labels)
    if not clusters:
        return {"status": "no_failures", "clusters_saved": 0}

    try:
        rows = save_clusters(db, clusters, strategy_id=strategy_id)
        db.commit()
        return {
            "status": "saved",
            "clusters_saved": len(rows),
            "cluster_names": [r.label for r in rows],
        }
    except Exception as e:
        db.rollback()
        logger.exception("[save-failure-clusters] DB write failed")
        return {"status": "error", "error": str(e), "clusters_saved": 0}
