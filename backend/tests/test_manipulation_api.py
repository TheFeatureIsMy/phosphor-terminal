"""Tests for Manipulation Radar API endpoints."""
from fastapi.testclient import TestClient


class TestManipulationScan:
    def test_scan_returns_score(self, client: TestClient):
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
        assert body["data_quality"]["layer_a"] is True

    def test_scan_missing_symbol(self, client: TestClient):
        resp = client.post("/api/v2/manipulation/scan", json={"timeframe": "1h"})
        assert resp.status_code == 422


class TestManipulationScoresList:
    def test_list_empty(self, client: TestClient):
        resp = client.get("/api/v2/manipulation/scores")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_list_after_scan(self, client: TestClient):
        client.post("/api/v2/manipulation/scan", json={"symbol": "ETH/USDT"})
        resp = client.get("/api/v2/manipulation/scores")
        assert resp.status_code == 200
        assert len(resp.json()) == 1
        assert resp.json()[0]["symbol"] == "ETH/USDT"

    def test_filter_by_risk_level(self, client: TestClient):
        client.post("/api/v2/manipulation/scan", json={"symbol": "BTC/USDT"})
        resp = client.get("/api/v2/manipulation/scores", params={"risk_level": "extreme"})
        assert resp.status_code == 200


class TestManipulationScoreBySymbol:
    def test_get_not_found(self, client: TestClient):
        resp = client.get("/api/v2/manipulation/scores/UNKNOWN/USDT")
        assert resp.status_code == 404

    def test_get_after_scan(self, client: TestClient):
        client.post("/api/v2/manipulation/scan", json={"symbol": "SOL/USDT"})
        resp = client.get("/api/v2/manipulation/scores/SOL/USDT")
        assert resp.status_code == 200
        assert resp.json()["symbol"] == "SOL/USDT"
