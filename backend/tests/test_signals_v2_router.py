"""Tests for Signal Center v2 API endpoints."""
from datetime import datetime, timedelta, timezone
import pytest


class TestCreateSignal:
    def test_create_signal_returns_201(self, client):
        resp = client.post("/api/v2/signals", json={
            "source_type": "ai_research",
            "symbol": "BTC/USDT",
            "direction": "long",
            "confidence": 0.85,
            "risk_level": "medium",
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat(),
            "reasoning": "Strong RSI divergence detected",
        })
        assert resp.status_code == 201
        data = resp.json()
        assert data["symbol"] == "BTC/USDT"
        assert data["direction"] == "long"
        assert data["status"] == "pending"

    def test_create_signal_invalid_confidence(self, client):
        resp = client.post("/api/v2/signals", json={
            "source_type": "manual",
            "symbol": "ETH/USDT",
            "direction": "short",
            "confidence": 1.5,  # Invalid: > 1
            "risk_level": "low",
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=12)).isoformat(),
            "reasoning": "test",
        })
        assert resp.status_code == 422

    def test_create_signal_invalid_direction(self, client):
        resp = client.post("/api/v2/signals", json={
            "source_type": "manual",
            "symbol": "ETH/USDT",
            "direction": "sideways",  # Invalid
            "confidence": 0.5,
            "risk_level": "low",
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=12)).isoformat(),
            "reasoning": "test",
        })
        assert resp.status_code == 422

    def test_create_signal_invalid_risk_level(self, client):
        resp = client.post("/api/v2/signals", json={
            "source_type": "manual",
            "symbol": "ETH/USDT",
            "direction": "long",
            "confidence": 0.5,
            "risk_level": "critical",  # Invalid: not in {low, medium, high, extreme}
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=12)).isoformat(),
            "reasoning": "test",
        })
        assert resp.status_code == 422


class TestListSignals:
    def test_list_empty(self, client):
        resp = client.get("/api/v2/signals")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_list_with_filter(self, client):
        # Create a signal first
        client.post("/api/v2/signals", json={
            "source_type": "manual",
            "symbol": "BTC/USDT",
            "direction": "long",
            "confidence": 0.7,
            "risk_level": "low",
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat(),
            "reasoning": "test",
        })
        resp = client.get("/api/v2/signals?symbol=BTC/USDT")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) >= 1
        assert all(s["symbol"] == "BTC/USDT" for s in data)

    def test_list_with_pagination(self, client):
        resp = client.get("/api/v2/signals?limit=10&offset=0")
        assert resp.status_code == 200


class TestTransition:
    def _create_signal(self, client):
        r = client.post("/api/v2/signals", json={
            "source_type": "manual",
            "symbol": "BTC/USDT",
            "direction": "long",
            "confidence": 0.7,
            "risk_level": "low",
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat(),
            "reasoning": "test",
        })
        assert r.status_code == 201
        return r.json()["id"]

    def test_transition_valid(self, client):
        signal_id = self._create_signal(client)
        # Transition pending -> active
        r2 = client.post(f"/api/v2/signals/{signal_id}/transition", json={
            "target_status": "active",
        })
        assert r2.status_code == 200
        assert r2.json()["status"] == "active"

    def test_transition_invalid(self, client):
        signal_id = self._create_signal(client)
        # Invalid: pending -> executed (not allowed)
        r2 = client.post(f"/api/v2/signals/{signal_id}/transition", json={
            "target_status": "executed",
        })
        assert r2.status_code == 409

    def test_transition_to_rejected(self, client):
        signal_id = self._create_signal(client)
        r2 = client.post(f"/api/v2/signals/{signal_id}/transition", json={
            "target_status": "rejected",
            "reason": "Not aligned with current market",
        })
        assert r2.status_code == 200
        assert r2.json()["status"] == "rejected"


class TestConflictCheck:
    def test_no_conflict(self, client):
        resp = client.post("/api/v2/signals/conflict-check", json={
            "symbol": "BTC/USDT",
            "direction": "long",
        })
        assert resp.status_code == 200
        assert resp.json()["has_conflict"] is False

    def test_conflict_detected(self, client):
        # Create a short signal
        client.post("/api/v2/signals", json={
            "source_type": "manual",
            "symbol": "ETH/USDT",
            "direction": "short",
            "confidence": 0.8,
            "risk_level": "medium",
            "expires_at": (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat(),
            "reasoning": "bearish divergence",
        })
        # Check conflict for a long on same symbol
        resp = client.post("/api/v2/signals/conflict-check", json={
            "symbol": "ETH/USDT",
            "direction": "long",
        })
        assert resp.status_code == 200
        assert resp.json()["has_conflict"] is True


class TestAggregate:
    def test_aggregate_empty(self, client):
        resp = client.post("/api/v2/signals/aggregate", json={
            "group_by": "symbol",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "groups" in data
        assert "total_count" in data
        assert data["total_count"] == 0

    def test_aggregate_invalid_group_by(self, client):
        resp = client.post("/api/v2/signals/aggregate", json={
            "group_by": "invalid_field",
        })
        assert resp.status_code == 422
