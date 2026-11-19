"""Tests for Risk BFF routes -- block/unblock, rules, circuit-breaker resolve"""
import pytest
from fastapi.testclient import TestClient
from app.main import app as fastapi_app


def test_block_new_entries_real(client, session):
    from app.models.system_settings import SystemSetting
    from app.services.account_risk_firewall import AccountRiskFirewall

    try:
        resp = client.post("/api/risk/block-new-entries", json={"reason": "manual"})
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "blocked"
        assert any(l["lock"] == "manual_block" for l in body["active_locks"])

        row = (
            session.query(SystemSetting)
            .filter_by(key=AccountRiskFirewall.MANUAL_BLOCK_KEY)
            .first()
        )
        assert row is not None
        assert row.value["active"] is True
    finally:
        client.post("/api/risk/unblock")


def test_unblock_real(client):
    client.post("/api/risk/block-new-entries", json={"reason": "manual"})
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


def test_put_rules_recomputes_policy_hash(client, session):
    import json

    from app.domain.risk import RiskPolicyVersion
    from app.utils import hash_string

    resp = client.put("/api/risk/rules", json={"daily_loss_limit": 3.5})
    assert resp.status_code == 200

    session.expire_all()
    row = (
        session.query(RiskPolicyVersion)
        .order_by(RiskPolicyVersion.created_at.desc())
        .first()
    )
    assert row is not None
    assert row.policy_hash == hash_string(json.dumps(row.policy_json, sort_keys=True))


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
