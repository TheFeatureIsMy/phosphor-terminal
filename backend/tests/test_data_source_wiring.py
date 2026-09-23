"""Phase 3 data-source tests — structure matrix real data path, sentiment
PRD endpoints, manipulation scan honest failure (no silent mocks).
"""
from __future__ import annotations

import asyncio
import random

import pytest

from app.models.strategy import SentimentData
from app.services.structure_matrix_service import StructureMatrixService


class _FakeMarketService:
    """MarketDataService stub returning deterministic synthetic OHLCV."""

    def __init__(self, candles_per_tf: int = 120, empty: bool = False):
        self._n = candles_per_tf
        self._empty = empty

    async def get_ohlcv(self, symbol: str, timeframe: str = "1d", limit: int = 100):
        if self._empty:
            return []
        rng = random.Random(7)
        candles = []
        price = 100.0
        ts = 1_700_000_000_000
        for i in range(min(limit, self._n)):
            change = rng.gauss(0, 0.01)
            open_ = price
            close = price * (1 + change)
            candles.append({
                "timestamp": ts + i * 300_000,
                "open": open_,
                "high": max(open_, close) * 1.002,
                "low": min(open_, close) * 0.998,
                "close": close,
                "volume": 1000 + rng.random() * 500,
            })
            price = close
        return candles


class TestStructureMatrixRealData:
    def test_no_market_data_returns_unavailable(self):
        svc = StructureMatrixService(market_data_service=_FakeMarketService(empty=True))
        result = asyncio.run(svc.get_matrix("BTC/USDT"))
        assert result.state == "data_source_unavailable"
        assert "market_data_missing" in result.reason_codes
        assert result.rows == []
        # The service must not expose any mock-matrix builder anymore
        assert not hasattr(svc, "_build_mock_matrix")

    def test_real_matrix_from_ohlcv(self):
        svc = StructureMatrixService(market_data_service=_FakeMarketService())
        result = asyncio.run(svc.get_matrix("BTC/USDT"))
        assert result.state in ("healthy", "warning")
        assert result.symbol == "BTC/USDT"
        assert len(result.rows) == len(StructureMatrixService.TIMEFRAMES)
        # Real analysis produces zone cells per timeframe
        first_row = result.rows[0]
        assert set(first_row.cells.keys()) == set(StructureMatrixService.ZONE_TYPES)
        for cell in first_row.cells.values():
            assert cell.status in ("active", "warning", "inactive", "unknown")

    def test_partial_timeframes_skipped(self):
        class _Partial(_FakeMarketService):
            async def get_ohlcv(self, symbol, timeframe="1d", limit=100):
                if timeframe == "4h":
                    return []
                return await super().get_ohlcv(symbol, timeframe, limit)

        svc = StructureMatrixService(market_data_service=_Partial())
        result = asyncio.run(svc.get_matrix("BTC/USDT"))
        by_tf = {r.timeframe: r for r in result.rows}
        assert by_tf["4h"].cells == {}
        assert by_tf["5m"].cells


class TestSentimentPrdEndpoints:
    def test_global_market_empty_state(self, client, session):
        r = client.get("/api/sentiment/market")
        assert r.status_code == 200
        body = r.json()
        assert body["state"] == "data_source_unavailable"
        assert body["reason_codes"] == ["sentiment_records_empty"]

    def test_global_market_with_records(self, client, session):
        session.add(SentimentData(symbol="BTC/USDT", source="news", score=0.8))
        session.add(SentimentData(symbol="ETH/USDT", source="twitter", score=0.3))
        session.commit()
        r = client.get("/api/sentiment/market")
        body = r.json()
        assert body["state"] == "healthy"
        assert len(body["market_overview"]) == 2
        assert "fear_greed_index" in body

    def test_news_and_social_filter_by_source(self, client, session):
        session.add(SentimentData(symbol="BTC/USDT", source="news", score=0.9, raw_text="bullish"))
        session.add(SentimentData(symbol="BTC/USDT", source="twitter", score=0.2, raw_text="bearish"))
        session.commit()

        news = client.get("/api/sentiment/news").json()
        assert news["state"] == "healthy"
        assert news["count"] == 1
        assert news["items"][0]["source"] == "news"

        social = client.get("/api/sentiment/social").json()
        assert social["state"] == "healthy"
        assert social["items"][0]["source"] == "twitter"

    def test_symbol_endpoint_alias(self, client, session):
        r = client.get("/api/sentiment/symbol/BTCUSDT?days=3")
        assert r.status_code == 200

    def test_legacy_prefix_still_served(self, client, session):
        r = client.get("/sentiment/summary")
        assert r.status_code == 200
        r2 = client.post("/sentiment/analyze", json={"text": "profit growth bullish"})
        assert r2.status_code == 200


class TestManipulationScanHonestFailure:
    def test_scan_503_when_market_data_unavailable(self, client, session, monkeypatch):
        import app.services.manipulation.data_adapter as da

        class _BrokenAdapter(da.MarketDataAdapter):
            def get_ohlcv(self, symbol, timeframe, limit=100):
                raise RuntimeError("no OHLCV data")

        monkeypatch.setattr(da, "LiveMarketDataAdapter", lambda: _BrokenAdapter())
        r = client.post("/api/v2/manipulation/scan", json={
            "symbol": "BTC/USDT", "timeframe": "1h",
        })
        assert r.status_code == 503
        detail = r.json()["detail"]
        assert detail["state"] == "data_source_unavailable"
        assert "market_data_unavailable" in detail["reason_codes"]
