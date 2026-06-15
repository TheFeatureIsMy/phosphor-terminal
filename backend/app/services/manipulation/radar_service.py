"""ManipulationRadarService — orchestrates feature computation and persistence."""
from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.manipulation import ManipulationScore
from app.services.manipulation.data_adapter import MarketDataAdapter, MockMarketDataAdapter
from app.services.manipulation.features import compute_all_features
from app.services.manipulation.scoring import ManipulationResult, compute_manipulation_scores
from app.services.manipulation.cross_market_adapter import MockCrossMarketAdapter
from app.services.manipulation.cross_market_features import compute_cross_market_features
from app.services.manipulation.orderbook_adapter import MockOrderbookAdapter
from app.services.manipulation.orderbook_features import compute_orderbook_features


class ManipulationRadarService:
    def __init__(self, session: Session, adapter: MarketDataAdapter | None = None):
        self._s = session
        self._adapter = adapter or MockMarketDataAdapter()

    def scan_symbol(self, symbol: str, timeframe: str = "1h") -> ManipulationResult:
        candles = self._adapter.get_ohlcv(symbol, timeframe, limit=100)
        ohlcv_features = compute_all_features(candles)

        # Fetch cross-market data (Layer E)
        cm_adapter = MockCrossMarketAdapter()
        cm_snapshots = cm_adapter.get_history(symbol, limit=50)
        cm_features = compute_cross_market_features([s.to_dict() for s in cm_snapshots])

        # Fetch orderbook data (Layer B)
        ob_adapter = MockOrderbookAdapter()
        ob_snapshots = ob_adapter.get_history(symbol, limit=60)
        ob_features = compute_orderbook_features([s.to_dict() for s in ob_snapshots])

        # Merge all features
        features = {**ohlcv_features, **cm_features, **ob_features}

        # Pass cross-market features to scoring
        result = compute_manipulation_scores(
            features, symbol=symbol, timeframe=timeframe,
            cross_market_features=cm_features,
        )

        record = ManipulationScore(
            symbol=symbol,
            timeframe=timeframe,
            scores=result.to_scores_dict(),
            risk_level=result.risk_level,
            features=result.features,
            reasoning=result.reasoning,
            data_quality=result.data_quality,
        )
        self._s.add(record)
        self._s.flush()
        result.features["_record_id"] = str(record.id)
        return result

    def get_latest_score(self, symbol: str) -> ManipulationScore | None:
        stmt = (
            select(ManipulationScore)
            .where(ManipulationScore.symbol == symbol)
            .order_by(ManipulationScore.created_at.desc())
            .limit(1)
        )
        return self._s.scalar(stmt)

    def list_scores(
        self, *, risk_level: str | None = None, limit: int = 50,
    ) -> list[ManipulationScore]:
        stmt = select(ManipulationScore)
        if risk_level:
            stmt = stmt.where(ManipulationScore.risk_level == risk_level)
        stmt = stmt.order_by(ManipulationScore.created_at.desc()).limit(limit)
        return list(self._s.scalars(stmt).all())
