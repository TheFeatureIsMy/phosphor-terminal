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

    def test_orderbook_features(self):
        from app.services.manipulation.orderbook_features import compute_orderbook_features
        from app.services.manipulation.orderbook_adapter import MockOrderbookAdapter
        adapter = MockOrderbookAdapter()
        snapshots = adapter.get_history("BTC/USDT", limit=60)
        features = compute_orderbook_features([s.to_dict() for s in snapshots])
        assert "spoof_score" in features
        assert "liquidity_void_score" in features
        assert all(0 <= v <= 100 for v in features.values())

    def test_classifier_detects_spoofing(self):
        from app.services.manipulation.classifier import ManipulationPatternClassifier
        clf = ManipulationPatternClassifier()
        features = {"spoof_score": 70, "depth_imbalance_score": 45, "spread_volatility": 55}
        matches = clf.classify(features)
        types = [m.manipulation_type for m in matches]
        assert "M7" in types

    def test_onchain_features(self):
        from app.services.manipulation.onchain_features import compute_onchain_features
        from app.services.manipulation.onchain_adapter import MockOnchainAdapter
        adapter = MockOnchainAdapter()
        snapshots = adapter.get_history("PEPE/USDT", limit=30)
        features = compute_onchain_features([s.to_dict() for s in snapshots])
        assert "holder_concentration_score" in features
        assert "exchange_inflow_zscore" in features
        assert all(0 <= v <= 100 for v in features.values())

    def test_social_features(self):
        from app.services.manipulation.social_features import compute_social_features
        from app.services.manipulation.social_adapter import MockSocialAdapter
        adapter = MockSocialAdapter()
        snapshots = adapter.get_history("DOGE/USDT", limit=48)
        features = compute_social_features([s.to_dict() for s in snapshots])
        assert "kol_pump_score" in features
        assert "retail_fomo_score" in features
        assert all(0 <= v <= 100 for v in features.values())

    def test_training_pipeline_extracts_samples(self):
        from app.services.manipulation.training_pipeline import ManipulationTrainingPipeline
        pipeline = ManipulationTrainingPipeline()
        case = {
            "id": "test-1", "symbol": "SOL/USDT", "market": "crypto",
            "manipulation_type": "M5", "lifecycle_stage": "completed",
            "timeline": [
                {"stage": "suspected", "features": {"volume_zscore": 45}},
                {"stage": "accumulate", "features": {"consolidation_score": 65}},
                {"stage": "markup", "features": {"breakout_velocity": 70, "funding_rate_zscore": 80}},
                {"stage": "distribute", "features": {"distribution_signature": 60}},
            ],
            "outcome": {"was_manipulation": True, "peak_price_change_pct": 180},
        }
        samples = pipeline.extract_samples_from_case(case)
        assert len(samples) == 4
        assert samples[0].lifecycle_stage == "suspected"
        assert samples[0].next_stage == "accumulate"
        assert samples[-1].next_stage == "completed"
        assert "A" in samples[2].available_layers
        assert "E" in samples[2].available_layers  # funding_rate_zscore → Layer E

    def test_rules_model_interface(self):
        from app.services.manipulation.model_interface import RulesBasedModel
        model = RulesBasedModel()
        assert model.model_version == "rules-v1"
        pred = model.predict({"pump_then_dump": 70, "volume_zscore": 60, "price_range_spike": 50})
        assert pred.manipulation_type != "none"
        assert pred.confidence > 0
        assert len(pred.type_probabilities) > 0


class TestDualSignal:
    def test_dual_signal_returns_both_profiles(self):
        from app.services.manipulation.lifecycle import ManipulationLifecycleTracker
        tracker = ManipulationLifecycleTracker()
        signals = tracker.generate_dual_signal("distribute")
        assert set(signals.keys()) == {"conservative", "aggressive"}
        assert signals["conservative"]["action"] == "EXIT"
        assert signals["aggressive"]["action"] == "EXIT_OR_SHORT"
        for profile in ("conservative", "aggressive"):
            for key in ("action", "direction", "sizing", "stop_loss", "rationale", "risk_level"):
                assert key in signals[profile]

    def test_dual_signal_unknown_stage_falls_back_to_suspected(self):
        from app.services.manipulation.lifecycle import ManipulationLifecycleTracker
        tracker = ManipulationLifecycleTracker()
        signals = tracker.generate_dual_signal("nonexistent")
        assert signals["conservative"]["action"] == "WATCH"
        assert signals["aggressive"]["action"] == "WATCH"


class TestCaseRepoEvidenceLayers:
    def test_create_case_stores_evidence_layers(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        layers = {
            "A_price": {"available": True, "data_quality": 0.9, "score": 0.7, "features": []},
            "B_orderbook": {"available": True, "data_quality": 0.6, "score": 0.4, "features": []},
            "D_social": {"available": False, "data_quality": 0.1, "score": None, "features": []},
        }
        case = repo.create_case(
            symbol="SOL/USDT", market="crypto", manipulation_type="M5",
            confidence=0.78, evidence={"volume_zscore": 2.4},
            evidence_layers=layers,
        )
        stored = repo.get_case(case["id"])
        assert stored["evidence_layers"] == layers
        assert stored["evidence"] == {"volume_zscore": 2.4}

    def test_create_case_without_evidence_layers_defaults_none(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        case = repo.create_case(
            symbol="BTC/USDT", market="crypto", manipulation_type="M1",
            confidence=0.5, evidence={},
        )
        assert case.get("evidence_layers") is None


class TestFindSimilar:
    def _layers(self, a, b, c, d, e):
        return {
            "A_price": {"available": True, "data_quality": 0.9, "score": a, "features": []},
            "B_orderbook": {"available": True, "data_quality": 0.9, "score": b, "features": []},
            "C_onchain": {"available": True, "data_quality": 0.9, "score": c, "features": []},
            "D_social": {"available": True, "data_quality": 0.9, "score": d, "features": []},
            "E_cross_market": {"available": True, "data_quality": 0.9, "score": e, "features": []},
        }

    def test_find_similar_returns_completed_cases_by_cosine(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        focal = repo.create_case(symbol="SOL/USDT", market="crypto", manipulation_type="M5",
                                 confidence=0.7, evidence={},
                                 evidence_layers=self._layers(0.8, 0.6, 0.7, 0.0, 0.9))
        sim = repo.create_case(symbol="LUNA/USDT", market="crypto", manipulation_type="M5",
                               confidence=0.7, evidence={},
                               evidence_layers=self._layers(0.78, 0.62, 0.71, 0.0, 0.88))
        repo.update_stage(sim["id"], "collapse", confidence=0.9)
        repo.update_stage(sim["id"], "completed", confidence=0.0)
        repo.set_outcome(sim["id"], {"peak_change": 2.4, "collapse_depth": -0.9, "duration_days": 14})
        dis = repo.create_case(symbol="DOGE/USDT", market="crypto", manipulation_type="M6",
                               confidence=0.4, evidence={},
                               evidence_layers=self._layers(0.1, 0.1, 0.1, 0.9, 0.1))
        repo.update_stage(dis["id"], "completed", confidence=0.0)

        results = repo.find_similar(focal["id"], top_n=5)
        assert len(results) == 2
        assert results[0]["id"] == sim["id"]
        assert results[0]["similarity"] > results[1]["similarity"]
        assert results[0]["outcome"]["peak_change"] == 2.4
        ids = [r["id"] for r in results]
        assert focal["id"] not in ids

    def test_find_similar_empty_when_no_completed_cases(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        focal = repo.create_case(symbol="SOL/USDT", market="crypto", manipulation_type="M5",
                                 confidence=0.7, evidence={},
                                 evidence_layers=self._layers(0.8, 0.6, 0.7, 0.0, 0.9))
        assert repo.find_similar(focal["id"]) == []

    def test_find_similar_returns_empty_when_focal_has_no_layers(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        focal = repo.create_case(symbol="SOL/USDT", market="crypto",
                                 manipulation_type="M5", confidence=0.7, evidence={})
        assert repo.find_similar(focal["id"]) == []



class TestPubsub:
    def test_publish_event_broadcasts_to_all_subscribers(self):
        from app.services.manipulation.pubsub import subscribe, unsubscribe, publish_event
        q1 = subscribe()
        q2 = subscribe()
        try:
            publish_event({"type": "new_case", "case_id": "x"})
            assert q1.get_nowait()["case_id"] == "x"
            assert q2.get_nowait()["case_id"] == "x"
        finally:
            unsubscribe(q1)
            unsubscribe(q2)

    def test_unsubscribe_stops_receiving(self):
        from app.services.manipulation.pubsub import subscribe, unsubscribe, publish_event
        q = subscribe()
        unsubscribe(q)
        publish_event({"type": "noop"})
        assert q.empty()

    def test_create_case_publishes_new_case_event(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        from app.services.manipulation.pubsub import subscribe, unsubscribe
        q = subscribe()
        try:
            repo = ManipulationCaseRepository()
            repo.create_case(symbol="SOL/USDT", market="crypto",
                             manipulation_type="M5", confidence=0.7, evidence={})
            evt = q.get_nowait()
            assert evt["type"] == "new_case"
            assert evt["symbol"] == "SOL/USDT"
            assert evt["initial_stage"] == "suspected"
        finally:
            unsubscribe(q)

    def test_update_stage_publishes_stage_change_event(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        from app.services.manipulation.pubsub import subscribe, unsubscribe
        repo = ManipulationCaseRepository()
        case = repo.create_case(symbol="SOL/USDT", market="crypto",
                                manipulation_type="M5", confidence=0.7, evidence={})
        q = subscribe()
        try:
            repo.update_stage(case["id"], "markup", confidence=0.8)
            evt = q.get_nowait()
            assert evt["type"] == "stage_change"
            assert evt["old_stage"] == "suspected"
            assert evt["new_stage"] == "markup"
        finally:
            unsubscribe(q)
