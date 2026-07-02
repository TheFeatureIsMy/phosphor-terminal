"""Tests for execution BFF endpoints."""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_cancel_single_order(monkeypatch):
    cancelled = {}

    class FakeClient:
        async def cancel_order(self, order_id):
            cancelled["id"] = order_id
            return {"status": "ok"}

    monkeypatch.setattr(
        "app.services.freqtrade_client.FreqtradeClient",
        lambda *a, **k: FakeClient(),
    )
    resp = client.post("/api/execution/orders/abc-123/cancel")
    assert resp.status_code == 200
    body = resp.json()
    assert body["cancelled_order_id"] == "abc-123"
    assert body["status"] == "cancelled"
    assert cancelled["id"] == "abc-123"


def test_close_single_position(monkeypatch):
    closed = {}

    class FakeClient:
        async def forceexit(self, trade_id):
            closed["id"] = trade_id
            return {"status": "ok"}

    monkeypatch.setattr(
        "app.services.freqtrade_client.FreqtradeClient",
        lambda *a, **k: FakeClient(),
    )
    resp = client.post("/api/execution/positions/pos-42/close")
    assert resp.status_code == 200
    body = resp.json()
    assert body["closed_position_id"] == "pos-42"
    assert body["status"] == "closed"
    assert closed["id"] == "pos-42"
