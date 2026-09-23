"""Tests for FailureClusteringService with real ExecutionTrade data."""
import uuid
from datetime import timedelta

import pytest
from sqlalchemy.orm import Session

from app.domain.order import ExecutionTrade
from app.services.failure_clustering import FailureClusteringService, cluster_failures


def _utcnow():
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _add_losing_trades(session: Session, n=10):
    now = _utcnow()
    for i in range(n):
        duration_min = 5 if i < 3 else 120  # first 3 are very short
        trade = ExecutionTrade(
            latest_ledger_event_id=uuid.uuid4(),
            source_system="freqtrade",
            source_trade_id=f"ft-fail-{i}",
            exchange="binance",
            symbol="BTC/USDT",
            side="long",
            profit_abs=-50.0 - i * 10,
            profit_pct=-0.03 - i * 0.005,
            status="closed",
            opened_at=now - timedelta(hours=i * 4),
            closed_at=now - timedelta(hours=i * 4) + timedelta(minutes=duration_min),
            last_synced_at=now,
        )
        session.add(trade)
    session.flush()


class TestFailureClusteringReal:
    @pytest.mark.asyncio
    async def test_summary_with_losing_trades(self, session: Session):
        _add_losing_trades(session, n=10)
        session.commit()

        svc = FailureClusteringService()
        result = await svc.get_summary()

        assert result["state"] == "healthy"
        assert result["total_loss_trades"] == 10
        assert result["total_loss_amount"] < 0
        assert len(result["clusters"]) > 0
        assert len(result["labels"]) > 0

    @pytest.mark.asyncio
    async def test_summary_empty_when_no_losses(self, session: Session):
        # Add only winning trades
        now = _utcnow()
        for i in range(5):
            trade = ExecutionTrade(
                latest_ledger_event_id=uuid.uuid4(),
                source_system="freqtrade",
                source_trade_id=f"ft-win-{i}",
                exchange="binance", symbol="BTC/USDT", side="long",
                profit_abs=50.0, profit_pct=0.03,
                status="closed",
                opened_at=now - timedelta(hours=i),
                closed_at=now - timedelta(hours=i) + timedelta(hours=1),
                last_synced_at=now,
            )
            session.add(trade)
        session.commit()

        svc = FailureClusteringService()
        result = await svc.get_summary()
        assert result["total_loss_trades"] == 0
        assert result["clusters"] == []

    def test_cluster_failures_labels_correctly(self):
        trades = [
            {"trade_id": "t1", "profit_pct": -0.04},
            {"trade_id": "t2", "profit_pct": -0.02},
            {"trade_id": "t3", "profit_pct": -0.06},
        ]
        labels = {
            "t1": ["stop_too_close_to_liquidity_pool"],
            "t2": ["stop_too_close_to_liquidity_pool"],
            "t3": ["failed_due_to_news_shock"],
        }
        clusters = cluster_failures(trades, labels)
        assert len(clusters) == 2
        names = {c.cluster_name for c in clusters}
        assert "stop_too_close_to_liquidity_pool" in names
        assert "failed_due_to_news_shock" in names
