"""Tests for Manipulation Radar API endpoints."""
import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def mock_radar_adapter(monkeypatch):
    from app.services.manipulation.radar_service import (
        ManipulationRadarService,
        MockMarketDataAdapter,
    )
    original_init = ManipulationRadarService.__init__

    def patched_init(
        self, session, adapter=None, cross_market_adapter=None,
        orderbook_adapter=None, social_adapter=None,
    ):
        if adapter is None:
            adapter = MockMarketDataAdapter()
        original_init(self, session, adapter, cross_market_adapter, orderbook_adapter, social_adapter)

    monkeypatch.setattr(ManipulationRadarService, "__init__", patched_init)
    yield


class TestManipulationScan:
    def test_scan_returns_score(self, client: TestClient, mock_radar_adapter):
        resp = client.post("/api/v2/manipulation/scan", json={
            "symbol": "BTC/USDT",
            "timeframe": "1h",
        })
        assert resp.status_code == 201
        body = resp.json()
        assert body["symbol"] == "BTC/USDT"
        assert body["timeframe"] == "1h"
        assert "manipulation_score" in body
        assert "risk_level" in body
        assert body["risk_level"] in ("low", "medium", "high", "extreme")

    def test_scan_missing_symbol(self, client: TestClient):
        resp = client.post("/api/v2/manipulation/scan", json={"timeframe": "1h"})
        assert resp.status_code == 422


class TestManipulationScoresList:
    def test_list_empty(self, client: TestClient):
        resp = client.get("/api/v2/manipulation/scores")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_list_after_scan(self, client: TestClient, mock_radar_adapter):
        client.post("/api/v2/manipulation/scan", json={"symbol": "ETH/USDT"})
        resp = client.get("/api/v2/manipulation/scores")
        assert resp.status_code == 200
        assert len(resp.json()) == 1
        assert resp.json()[0]["symbol"] == "ETH/USDT"

    def test_filter_by_risk_level(self, client: TestClient, mock_radar_adapter):
        client.post("/api/v2/manipulation/scan", json={"symbol": "BTC/USDT"})
        resp = client.get("/api/v2/manipulation/scores", params={"risk_level": "extreme"})
        assert resp.status_code == 200


class TestManipulationScoreBySymbol:
    def test_get_not_found(self, client: TestClient):
        resp = client.get("/api/v2/manipulation/scores/UNKNOWN/USDT")
        assert resp.status_code == 404

    def test_get_after_scan(self, client: TestClient, mock_radar_adapter):
        client.post("/api/v2/manipulation/scan", json={"symbol": "SOL/USDT"})
        resp = client.get("/api/v2/manipulation/scores/SOL/USDT")
        assert resp.status_code == 200
        assert resp.json()["symbol"] == "SOL/USDT"


class TestAffectedSymbolsExpansion:
    def test_affected_symbols_expands_usdt_to_stablecoin_pairs(self, client: TestClient, mock_radar_adapter):
        # 直接通过 repo 创建 case（scan 不产生 case）
        from app.routers.manipulation import _get_case_repo
        repo = _get_case_repo()
        case = repo.create_case(
            symbol="SOL/USDT", market="crypto", manipulation_type="M2",
            confidence=0.7, evidence={}, evidence_layers={},
        )
        resp = client.get(f"/api/v2/manipulation/cases/{case['id']}")
        assert resp.status_code == 200
        symbols = resp.json()["affected_symbols"]
        # SOL/USDT → 应含 SOL/USDT, SOL/USDC, SOL/FDUSD
        assert any("SOL/USDT" in s for s in symbols)
        assert len(symbols) >= 2  # 至少扩展出同基币对

    def test_affected_symbols_no_slash_keeps_original(self, client: TestClient, mock_radar_adapter):
        # 无 / 的 symbol 保持原样
        from app.routers.manipulation import _get_case_repo
        repo = _get_case_repo()
        case = repo.create_case(
            symbol="BTC", market="crypto", manipulation_type="M1",
            confidence=0.5, evidence={}, evidence_layers={},
        )
        resp = client.get(f"/api/v2/manipulation/cases/{case['id']}")
        assert resp.json()["affected_symbols"] == ["BTC"]


class TestCaseDetailV2:
    def test_case_detail_v2_includes_evidence_layers(self, client: TestClient, mock_radar_adapter):
        from app.routers.manipulation import _get_case_repo
        repo = _get_case_repo()
        case = repo.create_case(
            symbol="SOL/USDT", market="crypto", manipulation_type="M5",
            confidence=0.78, evidence={"price_volume": 0.8},
            evidence_layers={
                "price_volume": {"available": True, "score": 0.78, "quality": 0.95, "features": {}},
                "orderbook": {"available": True, "score": 0.42, "quality": 0.60, "features": {}},
                "onchain": {"available": False, "score": 0, "quality": 0.10, "features": {}},
            },
        )
        resp = client.get(f"/api/v2/manipulation/cases/{case['id']}")
        body = resp.json()
        assert "evidence_layers" in body
        assert body["evidence_layers"]["price_volume"]["score"] == 0.78
        assert "completeness" in body
        assert "max_confidence" in body
        assert "trading_signal" in body
        assert "conservative" in body["trading_signal"]
        assert "aggressive" in body["trading_signal"]


class TestStrategyImpact:
    """Strategy-impact endpoint tests.

    compute_strategy_impact(case, db) returns dict with affected_strategies list.
    The router imports it via 'from ... import' so we patch the router's reference.
    """

    def _make_case(self):
        from app.routers.manipulation import _get_case_repo
        return _get_case_repo().create_case(
            symbol="SOL/USDT", market="crypto", manipulation_type="M5",
            confidence=0.78, evidence={"price_volume": 0.8},
            evidence_layers={"price_volume": {"available": True, "score": 0.78, "quality": 0.95, "features": {}}})

    def test_strategy_impact_blocks_when_filter_enabled(self, client: TestClient, mock_radar_adapter, monkeypatch):
        case = self._make_case()

        def fake(case, db):
            return {
                "case_id": case["id"],
                "affected_strategies": [{
                    "strategy_id": "s1", "name": "BTC Mom", "matches_symbols": ["SOL/USDT"],
                    "manipulation_filter": {
                        "enabled": True, "would_block": True,
                        "reason_codes": ["confidence_exceeds_max_score"],
                    },
                }],
                "total_affected": 1,
                "total_protected": 1,
            }

        monkeypatch.setattr("app.routers.manipulation.compute_strategy_impact", fake)
        resp = client.get(f"/api/v2/manipulation/cases/{case['id']}/strategy-impact")
        assert resp.status_code == 200
        items = resp.json()["affected_strategies"]
        assert any(i["manipulation_filter"]["would_block"] for i in items)

    def test_strategy_impact_warns_when_filter_disabled(self, client: TestClient, mock_radar_adapter, monkeypatch):
        case = self._make_case()

        def fake(case, db):
            return {
                "case_id": case["id"],
                "affected_strategies": [{
                    "strategy_id": "s2", "name": "SOL Breakout", "matches_symbols": ["SOL/USDT"],
                    "manipulation_filter": {
                        "enabled": False, "would_block": False,
                        "reason_codes": ["filter_disabled"],
                    },
                }],
                "total_affected": 1,
                "total_protected": 0,
            }

        monkeypatch.setattr("app.routers.manipulation.compute_strategy_impact", fake)
        resp = client.get(f"/api/v2/manipulation/cases/{case['id']}/strategy-impact")
        items = resp.json()["affected_strategies"]
        assert items[0]["manipulation_filter"]["reason_codes"] == ["filter_disabled"]


class TestSimilarCases:
    def test_similar_cases_ranking_by_cosine(self, client: TestClient, mock_radar_adapter):
        from app.routers.manipulation import _get_case_repo
        repo = _get_case_repo()
        # Two completed cases with different similarity scores (A_price layer)
        for sym, score in [("DOGE/USDT", 0.8), ("WIF/USDT", 0.6)]:
            c = repo.create_case(symbol=sym, market="crypto", manipulation_type="M3",
                                 confidence=0.5, evidence={},
                                 evidence_layers={"A_price": {"available": True, "score": score, "quality": 0.9, "features": {}}})
            repo.update_stage(c["id"], "completed", confidence=0.9)
        focal = repo.create_case(symbol="SOL/USDT", market="crypto", manipulation_type="M3",
                                  confidence=0.5, evidence={},
                                  evidence_layers={"A_price": {"available": True, "score": 0.85, "quality": 0.9, "features": {}}})
        resp = client.get(f"/api/v2/manipulation/cases/{focal['id']}/similar?limit=5")
        assert resp.status_code == 200
        sims = resp.json()["similar"]
        assert len(sims) >= 1
        # Cosine descending order
        assert all(sims[i]["similarity"] >= sims[i+1]["similarity"] for i in range(len(sims) - 1))


class TestStreamPush:
    def test_stream_pushes_stage_change(self, client: TestClient, mock_radar_adapter):
        """WS subscribe then trigger update_stage, receive stage_change event."""
        from app.routers.manipulation import _get_case_repo
        import threading
        import time

        repo = _get_case_repo()
        case = repo.create_case(
            symbol="SOL/USDT", market="crypto", manipulation_type="M5",
            confidence=0.5, evidence={},
            evidence_layers={"A_price": {"available": True, "score": 0.7, "quality": 0.9, "features": {}}},
        )
        received = []
        with client.websocket_connect("/api/v2/manipulation/stream") as ws:
            # Receive snapshot
            snap = ws.receive_json()
            assert snap["type"] == "snapshot"

            # Trigger stage change from a thread
            def _push():
                time.sleep(0.3)
                repo.update_stage(case["id"], "markup", confidence=0.7)

            threading.Thread(target=_push, daemon=True).start()

            # Receive stage_change
            for _ in range(20):
                msg = ws.receive_json()
                received.append(msg)
                if msg.get("type") == "stage_change":
                    break

        assert any(m.get("type") == "stage_change" for m in received)
