"""ManipulationRadarService — orchestrates feature computation and persistence."""
from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.manipulation import ManipulationScore
from app.services.manipulation.data_adapter import MarketDataAdapter
from app.services.manipulation.cross_market_adapter import CrossMarketAdapter
from app.services.manipulation.orderbook_adapter import OrderbookAdapter
from app.services.manipulation.social_adapter import SocialAdapter
from app.services.manipulation.features import compute_all_features
from app.services.manipulation.scoring import ManipulationResult, compute_manipulation_scores
from app.services.manipulation.cross_market_features import compute_cross_market_features
from app.services.manipulation.orderbook_features import compute_orderbook_features
from app.services.manipulation.social_features import compute_social_features

# INTERNAL: test fixture / dev only — production paths must inject real adapters
from app.services.manipulation.data_adapter import MockMarketDataAdapter  # noqa: F401
from app.services.manipulation.cross_market_adapter import MockCrossMarketAdapter  # noqa: F401
from app.services.manipulation.orderbook_adapter import MockOrderbookAdapter  # noqa: F401
from app.services.manipulation.social_adapter import MockSocialAdapter  # noqa: F401


class ProviderNotConfiguredError(Exception):
    """Raised when an adapter required for manipulation scanning is not configured."""
    pass


class ManipulationRadarService:
    def __init__(
        self,
        session: Session,
        adapter: MarketDataAdapter | None = None,
        cross_market_adapter: CrossMarketAdapter | None = None,
        orderbook_adapter: OrderbookAdapter | None = None,
        social_adapter: SocialAdapter | None = None,
    ):
        self._s = session
        self._adapter = adapter
        self._cm_adapter = cross_market_adapter
        self._ob_adapter = orderbook_adapter
        self._social_adapter = social_adapter

    def scan_symbol(self, symbol: str, timeframe: str = "1h") -> ManipulationResult:
        if self._adapter is None:
            raise ProviderNotConfiguredError("MarketDataAdapter is not configured — cannot fetch OHLCV data")

        candles = self._adapter.get_ohlcv(symbol, timeframe, limit=100)
        ohlcv_features = compute_all_features(candles)

        # Fetch cross-market data (Layer E)
        cm_features: dict[str, Any] = {}
        if self._cm_adapter is not None:
            cm_snapshots = self._cm_adapter.get_history(symbol, limit=50)
            cm_features = compute_cross_market_features([s.to_dict() for s in cm_snapshots])

        # Fetch orderbook data (Layer B)
        ob_features: dict[str, Any] = {}
        if self._ob_adapter is not None:
            ob_snapshots = self._ob_adapter.get_history(symbol, limit=60)
            ob_features = compute_orderbook_features([s.to_dict() for s in ob_snapshots])

        # Fetch social/news data (Layer D)
        social_features: dict[str, Any] = {}
        if self._social_adapter is not None:
            social_snapshots = self._social_adapter.get_history(symbol, limit=48)
            social_features = compute_social_features([s.to_dict() for s in social_snapshots])

        # Merge all features
        features = {**ohlcv_features, **cm_features, **ob_features, **social_features}

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
