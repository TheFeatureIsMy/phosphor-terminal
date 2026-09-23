"""Tests for GrowthAttributionService."""
import uuid
from datetime import timedelta

import pytest
from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun, FreqtradeRun
from app.domain.feature import FeatureSnapshot
from app.domain.order import ExecutionTrade
from app.domain.strategy import StrategyV2, StrategyVersion
from app.services.growth.attribution_service import GrowthAttributionService, AttributionResult


def _utcnow():
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _setup_with_trades(session: Session, n_wins=8, n_losses=4):
    """Create strategy + trades + feature snapshots."""
    strategy = StrategyV2(name="Attr Test", strategy_type="rule_dsl", source_type="manual", status="active")
    session.add(strategy)
    session.flush()

    version = StrategyVersion(
        strategy_id=strategy.id, version_no=1, status="paper_running",
        dsl_version="2.5", rule_dsl={}, dsl_hash="x", created_by="test",
    )
    session.add(version)
    session.flush()

    run = StrategyRun(
        strategy_version_id=version.id, mode="dry_run", status="running", started_at=_utcnow() - timedelta(days=7),
    )
    session.add(run)
    session.flush()

    now = _utcnow()
    for i in range(n_wins + n_losses):
        is_win = i < n_wins
        opened = now - timedelta(hours=(n_wins + n_losses - i) * 4)
        closed = opened + timedelta(hours=2)

        trade = ExecutionTrade(
            latest_ledger_event_id=uuid.uuid4(),
            strategy_run_id=run.id,
            source_system="freqtrade",
            source_trade_id=f"ft-attr-{i}",
            exchange="binance",
            symbol="BTC/USDT",
            side="long",
            open_rate=42000 + i * 100,
            close_rate=(42000 + i * 100) * (1.02 if is_win else 0.98),
            amount=0.01,
            profit_abs=8.4 if is_win else -8.4,
            profit_pct=0.02 if is_win else -0.02,
            status="closed",
            opened_at=opened,
            closed_at=closed,
            last_synced_at=now,
        )
        session.add(trade)
        session.flush()

        # Create feature snapshot near trade open time
        snap = FeatureSnapshot(
            id=uuid.uuid4(),
            snapshot_at=opened,
            symbol="BTC/USDT",
            feature_version="2.5",
            strategy_version_id=version.id,
            strategy_run_id=run.id,
            technical_features={
                "rsi_14": 35.0 + i * 2 if is_win else 65.0 + i,
                "macd_signal": 0.01 if is_win else -0.02,
                "volume_ratio": 1.5 + i * 0.1 if is_win else 0.8,
                "bb_width": 0.03 if is_win else 0.08,
                "momentum_5": 0.02 if is_win else -0.01,
            },
        )
        session.add(snap)

    session.flush()
    return run, version


class TestGrowthAttributionService:
    def test_insufficient_data(self, session: Session):
        run, version = _setup_with_trades(session, n_wins=2, n_losses=1)
        session.commit()

        svc = GrowthAttributionService(session)
        result = svc.compute_attribution(strategy_run_id=run.id, min_trades=10)

        assert result.sufficient_data is False
        assert result.total_trades_analyzed <= 3

    def test_heuristic_attribution_with_enough_data(self, session: Session):
        run, version = _setup_with_trades(session, n_wins=8, n_losses=4)
        session.commit()

        svc = GrowthAttributionService(session)
        result = svc.compute_attribution(
            strategy_run_id=run.id,
            strategy_version_id=version.id,
            min_trades=5,
        )

        assert result.sufficient_data is True
        assert result.total_trades_analyzed >= 5
        assert len(result.feature_importances) > 0
        assert result.model_type in ("heuristic", "shap_lightgbm")

        # Importances sum to ~1.0
        total_imp = sum(f["importance"] for f in result.feature_importances)
        assert 0.9 <= total_imp <= 1.1

    def test_win_and_loss_drivers_populated(self, session: Session):
        run, version = _setup_with_trades(session, n_wins=8, n_losses=4)
        session.commit()

        svc = GrowthAttributionService(session)
        result = svc.compute_attribution(
            strategy_run_id=run.id,
            strategy_version_id=version.id,
            min_trades=5,
        )

        # At least some drivers should be identified
        assert len(result.win_drivers) > 0 or len(result.loss_drivers) > 0

    def test_no_snapshots_returns_insufficient(self, session: Session):
        """Trades without feature snapshots → insufficient data."""
        strategy = StrategyV2(name="No Snap", strategy_type="rule_dsl", source_type="manual", status="active")
        session.add(strategy)
        session.flush()
        version = StrategyVersion(
            strategy_id=strategy.id, version_no=1, status="paper_running",
            dsl_version="2.5", rule_dsl={}, dsl_hash="x", created_by="test",
        )
        session.add(version)
        session.flush()
        run = StrategyRun(strategy_version_id=version.id, mode="dry_run", status="running", started_at=_utcnow())
        session.add(run)
        session.flush()

        # Add trades without snapshots
        now = _utcnow()
        for i in range(15):
            trade = ExecutionTrade(
                latest_ledger_event_id=uuid.uuid4(),
                strategy_run_id=run.id,
                source_system="freqtrade",
                source_trade_id=f"ft-nosnap-{i}",
                exchange="binance", symbol="ETH/USDT", side="long",
                profit_abs=5.0 if i % 2 == 0 else -5.0,
                profit_pct=0.01 if i % 2 == 0 else -0.01,
                status="closed", last_synced_at=now,
            )
            session.add(trade)
        session.commit()

        svc = GrowthAttributionService(session)
        result = svc.compute_attribution(strategy_run_id=run.id, min_trades=5)
        assert result.sufficient_data is False
