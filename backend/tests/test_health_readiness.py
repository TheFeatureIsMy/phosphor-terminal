"""Deployment readiness probe: DB/Redis required, Freqtrade reported."""
from unittest.mock import AsyncMock


def test_readiness_ready_with_db_redis_freqtrade(client, monkeypatch):
    monkeypatch.setattr("app.routers.health._redis_ready", AsyncMock(return_value=True))
    monkeypatch.setattr(
        "app.routers.health.freqtrade_client.ping", AsyncMock(return_value=True)
    )
    monkeypatch.setattr("app.routers.health.check_db", lambda: True)

    resp = client.get("/readiness")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ready"
    assert body["database"] == "connected"
    assert body["redis"] == "connected"
    assert body["freqtrade"] == "connected"
    assert body["reason_codes"] == []


def test_readiness_not_ready_without_redis(client, monkeypatch):
    monkeypatch.setattr("app.routers.health._redis_ready", AsyncMock(return_value=False))
    monkeypatch.setattr(
        "app.routers.health.freqtrade_client.ping", AsyncMock(return_value=False)
    )
    monkeypatch.setattr("app.routers.health.check_db", lambda: True)

    resp = client.get("/readiness")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "not_ready"
    assert "redis_unavailable" in body["reason_codes"]
    assert "freqtrade_unavailable" in body["reason_codes"]


def test_readiness_is_public(client, monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "auth_required", True)
    monkeypatch.setattr("app.routers.health._redis_ready", AsyncMock(return_value=True))
    monkeypatch.setattr(
        "app.routers.health.freqtrade_client.ping", AsyncMock(return_value=True)
    )
    assert client.get("/readiness").status_code == 200
