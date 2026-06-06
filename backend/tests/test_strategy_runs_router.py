"""Tests for Strategy Runs API."""
import uuid


class TestListRuns:
    def test_list_empty(self, client):
        resp = client.get("/api/v2/strategy-runs")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_list_with_mode_filter(self, client):
        resp = client.get("/api/v2/strategy-runs?mode=backtest")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_list_with_status_filter(self, client):
        resp = client.get("/api/v2/strategy-runs?status=running")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_list_pagination(self, client):
        resp = client.get("/api/v2/strategy-runs?limit=10&offset=0")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)


class TestGetRun:
    def test_not_found(self, client):
        resp = client.get(f"/api/v2/strategy-runs/{uuid.uuid4()}")
        assert resp.status_code == 404

    def test_not_found_detail_message(self, client):
        resp = client.get(f"/api/v2/strategy-runs/{uuid.uuid4()}")
        assert resp.status_code == 404
        assert "not found" in resp.json()["detail"].lower()


class TestGetRunOrders:
    def test_not_found(self, client):
        resp = client.get(f"/api/v2/strategy-runs/{uuid.uuid4()}/orders")
        assert resp.status_code == 404

    def test_not_found_with_pagination(self, client):
        resp = client.get(f"/api/v2/strategy-runs/{uuid.uuid4()}/orders?limit=10&offset=0")
        assert resp.status_code == 404


class TestGetRunLedger:
    def test_not_found(self, client):
        resp = client.get(f"/api/v2/strategy-runs/{uuid.uuid4()}/ledger")
        assert resp.status_code == 404
