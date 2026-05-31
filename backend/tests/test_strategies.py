"""Tests for strategies endpoints."""

from unittest.mock import patch, AsyncMock

from fastapi.testclient import TestClient


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# GET /api/strategies
# ---------------------------------------------------------------------------

class TestListStrategies:
    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_list_empty(self, _mock, client: TestClient):
        resp = client.get("/api/strategies")
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 0
        assert body["items"] == []
        assert body["page"] == 1

    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_list_paginated(self, _mock, client: TestClient):
        # Create 3 strategies
        for i in range(3):
            _create_strategy(client, name=f"Strat {i}")

        resp = client.get("/api/strategies", params={"page": 1, "page_size": 2})
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 3
        assert len(body["items"]) == 2
        assert body["pages"] == 2

        resp2 = client.get("/api/strategies", params={"page": 2, "page_size": 2})
        assert resp2.status_code == 200
        assert len(resp2.json()["items"]) == 1


# ---------------------------------------------------------------------------
# POST /api/strategies
# ---------------------------------------------------------------------------

class TestCreateStrategy:
    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_create_success(self, _mock, client: TestClient):
        resp = _create_strategy(client)
        assert resp.status_code == 201
        body = resp.json()
        assert body["name"] == "My Strategy"
        assert body["type"] == "ma_cross"
        assert body["status"] == "draft"
        assert body["market"] == "crypto"
        assert body["freqtrade_strategy_id"] == "PulseDesk1MyStrategy"

    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_create_invalid_market(self, _mock, client: TestClient):
        resp = _create_strategy(client, market="nonexistent_market")
        assert resp.status_code == 400


# ---------------------------------------------------------------------------
# GET /api/strategies/{id}
# ---------------------------------------------------------------------------

class TestGetStrategy:
    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_get_found(self, _mock, client: TestClient):
        created = _create_strategy(client).json()
        resp = client.get(f"/api/strategies/{created['id']}")
        assert resp.status_code == 200
        assert resp.json()["name"] == "My Strategy"

    def test_get_not_found(self, client: TestClient):
        resp = client.get("/api/strategies/9999")
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# PUT /api/strategies/{id}
# ---------------------------------------------------------------------------

class TestUpdateStrategy:
    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_update_success(self, _mock, client: TestClient):
        created = _create_strategy(client).json()
        resp = client.put(f"/api/strategies/{created['id']}", json={
            "name": "Updated Strategy",
            "parameters": {"fast_period": 5, "slow_period": 20},
        })
        assert resp.status_code == 200
        body = resp.json()
        assert body["name"] == "Updated Strategy"
        assert body["parameters"]["fast_period"] == 5

    def test_update_not_found(self, client: TestClient):
        resp = client.put("/api/strategies/9999", json={"name": "X"})
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# DELETE /api/strategies/{id}
# ---------------------------------------------------------------------------

class TestDeleteStrategy:
    @patch("app.routers.strategies.delete_strategy_file")
    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_delete_success(self, _reg_mock, _del_mock, client: TestClient):
        created = _create_strategy(client).json()
        resp = client.delete(f"/api/strategies/{created['id']}")
        assert resp.status_code == 204

        # Confirm it's gone
        resp2 = client.get(f"/api/strategies/{created['id']}")
        assert resp2.status_code == 404

    def test_delete_not_found(self, client: TestClient):
        resp = client.delete("/api/strategies/9999")
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# POST /api/strategies/{id}/deploy
# ---------------------------------------------------------------------------

class TestDeployStrategy:
    @patch("app.routers.strategies.freqtrade_client")
    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_deploy_success(self, _reg_mock, mock_ft, client: TestClient):
        mock_ft.start_bot = AsyncMock(return_value={"status": "started"})
        mock_ft.is_success.return_value = True

        created = _create_strategy(client).json()
        assert created["status"] == "draft"

        resp = client.post(f"/api/strategies/{created['id']}/deploy")
        assert resp.status_code == 200
        assert resp.json()["status"] == "active"

    @patch("app.routers.strategies.freqtrade_client")
    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_deploy_already_active(self, _reg_mock, mock_ft, client: TestClient):
        mock_ft.start_bot = AsyncMock(return_value={"status": "started"})
        mock_ft.is_success.return_value = True

        created = _create_strategy(client).json()
        # Deploy once
        client.post(f"/api/strategies/{created['id']}/deploy")
        # Deploy again should fail
        resp = client.post(f"/api/strategies/{created['id']}/deploy")
        assert resp.status_code == 400
        assert "already active" in resp.json()["detail"]

    def test_deploy_not_found(self, client: TestClient):
        resp = client.post("/api/strategies/9999/deploy")
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# POST /api/strategies/{id}/stop
# ---------------------------------------------------------------------------

class TestStopStrategy:
    @patch("app.routers.strategies.freqtrade_client")
    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_stop_success(self, _reg_mock, mock_ft, client: TestClient):
        mock_ft.start_bot = AsyncMock(return_value={"status": "started"})
        mock_ft.stop_bot = AsyncMock(return_value={"status": "stopped"})
        mock_ft.is_success.return_value = True

        created = _create_strategy(client).json()
        client.post(f"/api/strategies/{created['id']}/deploy")

        resp = client.post(f"/api/strategies/{created['id']}/stop")
        assert resp.status_code == 200
        assert resp.json()["status"] == "paused"

    @patch("app.routers.strategies.register_strategy_file", return_value="PulseDesk1MyStrategy")
    def test_stop_not_active(self, _reg_mock, client: TestClient):
        created = _create_strategy(client).json()  # status is "draft"
        resp = client.post(f"/api/strategies/{created['id']}/stop")
        assert resp.status_code == 400
        assert "not active" in resp.json()["detail"]

    def test_stop_not_found(self, client: TestClient):
        resp = client.post("/api/strategies/9999/stop")
        assert resp.status_code == 404
