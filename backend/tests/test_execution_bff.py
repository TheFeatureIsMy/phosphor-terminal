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


def test_cancel_all_orders(monkeypatch):
    cancelled = []

    class FakeClient:
        async def get_status(self):
            return [
                {
                    "trade_id": "t1",
                    "orders": [
                        {"order_id": "o1", "status": "open"},
                        {"order_id": "o2", "status": "open"},
                    ],
                },
                {
                    "trade_id": "t2",
                    "orders": [
                        {"order_id": "o3", "status": "open"},
                    ],
                },
            ]

        async def cancel_order(self, order_id):
            cancelled.append(order_id)
            return {"status": "ok"}

    monkeypatch.setattr(
        "app.services.freqtrade_client.FreqtradeClient",
        lambda *a, **k: FakeClient(),
    )
    resp = client.post("/api/execution/orders/cancel-all")
    assert resp.status_code == 200
    body = resp.json()
    assert body["affected_count"] == 3
    assert body["status"] == "cancelled"
    assert len(cancelled) == 3


def test_force_close_all_positions(monkeypatch):
    closed = []

    class FakeClient:
        async def get_status(self):
            return [
                {"trade_id": "t1", "is_open": True},
                {"trade_id": "t2", "is_open": True},
                {"trade_id": "t3", "is_open": True},
            ]

        async def forceexit(self, trade_id):
            closed.append(trade_id)
            return {"status": "ok"}

    monkeypatch.setattr(
        "app.services.freqtrade_client.FreqtradeClient",
        lambda *a, **k: FakeClient(),
    )
    resp = client.post("/api/execution/positions/force-close-all")
    assert resp.status_code == 200
    body = resp.json()
    assert body["affected_count"] == 3
    assert body["status"] == "closed"
    assert len(closed) == 3


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
