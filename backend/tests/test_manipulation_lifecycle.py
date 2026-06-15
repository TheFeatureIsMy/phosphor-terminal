"""Tests for Manipulation Radar lifecycle engine + API endpoints."""
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


class TestManipulationRadar:
    @pytest.mark.anyio
    async def test_radar_overview_200(self, client):
        r = await client.get("/api/v2/manipulation/radar")
        assert r.status_code == 200
        data = r.json()
        assert "active_cases" in data
        assert "total_active" in data
        assert "by_stage" in data

    @pytest.mark.anyio
    async def test_cases_list_200(self, client):
        r = await client.get("/api/v2/manipulation/cases")
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    @pytest.mark.anyio
    async def test_alerts_200(self, client):
        r = await client.get("/api/v2/manipulation/alerts")
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    @pytest.mark.anyio
    async def test_signals_200(self, client):
        r = await client.get("/api/v2/manipulation/signals?user_profile=aggressive")
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    @pytest.mark.anyio
    async def test_historical_scan_200(self, client):
        r = await client.post("/api/v2/manipulation/historical-scan?symbol=BTC/USDT&limit=100")
        assert r.status_code == 200
        data = r.json()
        assert "scanned_candles" in data
        assert "events_detected" in data


class TestLifecycleEngine:
    def test_lifecycle_transitions(self):
        from app.services.manipulation.lifecycle import ManipulationLifecycleTracker
        tracker = ManipulationLifecycleTracker()
        # Suspected → Accumulate when consolidation is high
        new = tracker.evaluate_transition("suspected", {"consolidation_score": 60})
        assert new == "accumulate"
        # Accumulate → Markup when breakout + volume
        new = tracker.evaluate_transition("accumulate", {"breakout_velocity": 60, "volume_zscore": 50})
        assert new == "markup"

    def test_classifier_detects_patterns(self):
        from app.services.manipulation.classifier import ManipulationPatternClassifier
        clf = ManipulationPatternClassifier()
        # M5: Cross-market manipulation
        features = {"pump_then_dump": 70, "volume_zscore": 60, "price_range_spike": 50}
        matches = clf.classify(features)
        assert len(matches) > 0
        assert matches[0].manipulation_type == "M5"

    def test_signal_generation(self):
        from app.services.manipulation.lifecycle import ManipulationLifecycleTracker
        tracker = ManipulationLifecycleTracker()
        sig = tracker.generate_signal("accumulate", "aggressive")
        assert sig.action == "AMBUSH"
        sig = tracker.generate_signal("accumulate", "conservative")
        assert sig.action == "WATCH"

    def test_cross_market_features(self):
        from app.services.manipulation.cross_market_features import compute_cross_market_features
        from app.services.manipulation.cross_market_adapter import MockCrossMarketAdapter
        adapter = MockCrossMarketAdapter()
        snapshots = adapter.get_history("BTC/USDT", limit=50)
        features = compute_cross_market_features([s.to_dict() for s in snapshots])
        assert "funding_rate_zscore" in features
        assert "cross_market_squeeze_score" in features
        assert all(0 <= v <= 100 for v in features.values())

    def test_scoring_with_cross_market(self):
        from app.services.manipulation.scoring import compute_manipulation_scores
        features = {"wick_ratio_up": 30, "volume_zscore": 50, "pump_then_dump": 60}
        cm = {"cross_market_squeeze_score": 70, "funding_rate_zscore": 65}
        result = compute_manipulation_scores(features, "TEST", "1h", cross_market_features=cm)
        assert result.funding_squeeze_score > 0
