"""Tests for strategies endpoints (v2.5 cleaned)."""
from fastapi.testclient import TestClient


STRATEGY_PAYLOAD = {
    "name": "My Strategy",
    "type": "ma_cross",
    "parameters": {"fast_period": 10, "slow_period": 30},
    "market": "crypto",
    "exchange": "binance",
}


def _create_strategy(client: TestClient, **overrides):
    payload = {**STRATEGY_PAYLOAD, **overrides}
    return client.post("/api/strategies", json=payload)


class TestListStrategies:
    def test_list_empty(self, client: TestClient):
        resp = client.get("/api/strategies")
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 0

    def test_list_paginated(self, client: TestClient):
        for i in range(3):
            _create_strategy(client, name=f"Strat {i}")
        resp = client.get("/api/strategies", params={"page": 1, "page_size": 2})
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 3
        assert len(body["items"]) == 2


class TestCreateStrategy:
    def test_create_success(self, client: TestClient):
        resp = _create_strategy(client)
        assert resp.status_code == 201
        body = resp.json()
        assert body["name"] == "My Strategy"
        assert body["status"] == "draft"

    def test_create_invalid_market(self, client: TestClient):
        resp = _create_strategy(client, market="nonexistent_market")
        assert resp.status_code == 400


class TestGetStrategy:
    def test_get_found(self, client: TestClient):
        created = _create_strategy(client).json()
        resp = client.get(f"/api/strategies/{created['id']}")
        assert resp.status_code == 200
        assert resp.json()["name"] == "My Strategy"

    def test_get_not_found(self, client: TestClient):
        resp = client.get("/api/strategies/9999")
        assert resp.status_code == 404


class TestUpdateStrategy:
    def test_update_success(self, client: TestClient):
        created = _create_strategy(client).json()
        resp = client.put(f"/api/strategies/{created['id']}", json={"name": "Updated"})
        assert resp.status_code == 200
        assert resp.json()["name"] == "Updated"

    def test_update_not_found(self, client: TestClient):
        resp = client.put("/api/strategies/9999", json={"name": "X"})
        assert resp.status_code == 404


class TestDeleteStrategy:
    def test_delete_success(self, client: TestClient):
        created = _create_strategy(client).json()
        resp = client.delete(f"/api/strategies/{created['id']}")
        assert resp.status_code == 204
        resp2 = client.get(f"/api/strategies/{created['id']}")
        assert resp2.status_code == 404

    def test_delete_not_found(self, client: TestClient):
        resp = client.delete("/api/strategies/9999")
        assert resp.status_code == 404


class TestDeployStrategy:
    def test_deploy_returns_501(self, client: TestClient):
        created = _create_strategy(client).json()
        resp = client.post(f"/api/strategies/{created['id']}/deploy")
        assert resp.status_code == 501

    def test_deploy_not_found(self, client: TestClient):
        resp = client.post("/api/strategies/9999/deploy")
        assert resp.status_code == 501


class TestStopStrategy:
    def test_stop_returns_501(self, client: TestClient):
        created = _create_strategy(client).json()
        resp = client.post(f"/api/strategies/{created['id']}/stop")
        assert resp.status_code == 501

    def test_stop_not_found(self, client: TestClient):
        resp = client.post("/api/strategies/9999/stop")
        assert resp.status_code == 501
