"""Tests for Risk BFF routes -- block/unblock, rules, circuit-breaker resolve"""
import pytest
from fastapi.testclient import TestClient
from app.main import app as fastapi_app


def test_block_new_entries_real(monkeypatch):
    client = TestClient(fastapi_app, raise_server_exceptions=False)

    # activate_manual_block is a classmethod -- no self arg
    monkeypatch.setattr(
        "app.services.account_risk_firewall.AccountRiskFirewall.activate_manual_block",
        lambda reason: [{"lock": "manual_block", "reason": reason}],
    )
    resp = client.post("/api/risk/block-new-entries", json={"reason": "manual"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "blocked"
    assert any(l["lock"] == "manual_block" for l in body["active_locks"])


def test_unblock_real(monkeypatch):
    client = TestClient(fastapi_app, raise_server_exceptions=False)

    # deactivate_manual_block is a classmethod -- no self arg
    monkeypatch.setattr(
        "app.services.account_risk_firewall.AccountRiskFirewall.deactivate_manual_block",
        lambda: [],
    )
    resp = client.post("/api/risk/unblock")
    assert resp.status_code == 200
    assert resp.json()["status"] == "unblocked"
    assert resp.json()["active_locks"] == []


def test_get_risk_rules():
    client = TestClient(fastapi_app, raise_server_exceptions=False)
    resp = client.get("/api/risk/rules")
    assert resp.status_code == 200
    body = resp.json()
    assert "daily_loss_limit" in body
    assert "kill_switch" in body
    assert "active" in body["kill_switch"]


def test_resolve_circuit_breaker(monkeypatch):
    client = TestClient(fastapi_app, raise_server_exceptions=False)

    class FakeRepo:
        def get(self, event_id):
            class E:
                event_type = "daily_loss_lock"
                resolved = False
            return E()

        def mark_resolved(self, event_id):
            pass

    monkeypatch.setattr(
        "app.services.circuit_breaker_repository.CircuitBreakerRepository",
        lambda *a, **k: FakeRepo(),
    )
    resp = client.post("/api/risk/circuit-breakers/evt-1/resolve")
    assert resp.status_code == 200
    assert resp.json()["resolved_event_id"] == "evt-1"


def test_old_risk_emergency_stop_deprecated():
    """Old /api/risk/emergency-stop GET and POST should return 410."""
    client = TestClient(fastapi_app, raise_server_exceptions=False)
    resp = client.get("/api/risk/emergency-stop")
    assert resp.status_code == 410
    assert "deprecated" in resp.json()["detail"].lower()
    resp = client.post("/api/risk/emergency-stop", json={"reason": "test"})
    assert resp.status_code == 410
    assert "deprecated" in resp.json()["detail"].lower()


def test_old_risk_emergency_resume_deprecated():
    """Old /api/risk/emergency-resume POST should return 410."""
    client = TestClient(fastapi_app, raise_server_exceptions=False)
    resp = client.post("/api/risk/emergency-resume", json={"strategy_run_id": "00000000-0000-0000-0000-000000000000"})
    assert resp.status_code == 410
    assert "deprecated" in resp.json()["detail"].lower()


def test_resolve_kill_switch_rejected(monkeypatch):
    client = TestClient(fastapi_app, raise_server_exceptions=False)

    class FakeRepo:
        def get(self, event_id):
            class E:
                event_type = "kill_switch"
                resolved = False
            return E()

    monkeypatch.setattr(
        "app.services.circuit_breaker_repository.CircuitBreakerRepository",
        lambda *a, **k: FakeRepo(),
    )
    resp = client.post("/api/risk/circuit-breakers/evt-2/resolve")
    assert resp.status_code == 409
