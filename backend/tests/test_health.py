"""Tests for health endpoints."""
from fastapi.testclient import TestClient


class TestHealth:
    def test_health(self, client: TestClient):
        resp = client.get("/health")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "ok"
        assert body["version"] == "2.5.0"

    def test_readiness(self, client: TestClient):
        resp = client.get("/readiness")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] in ("ready", "not_ready")
