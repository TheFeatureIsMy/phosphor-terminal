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
