"""Tests for reconciliation retry endpoints."""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


class _FakeReconService:
    """Fake for monkeypatch — records run_id passed to run_reconciliation."""
    def __init__(self, *args, **kwargs):
        self.run_id = None

    def run_reconciliation(self, run_id=None):
        self.run_id = run_id
        return {"affected": 1}


def test_retry_single_recon_run(monkeypatch):
    fake = _FakeReconService()
    monkeypatch.setattr(
        "app.services.reconciliation_service.ReconciliationService",
        lambda *a, **k: fake,
    )
    resp = client.post("/api/reconciliation/runs/recon-9/retry")
    assert resp.status_code == 200
    body = resp.json()
    assert body["run_id"] == "recon-9"
    assert body["status"] == "retrying"
    assert fake.run_id == "recon-9"


def test_retry_all_recon(monkeypatch):
    fake = _FakeReconService()
    monkeypatch.setattr(
        "app.services.reconciliation_service.ReconciliationService",
        lambda *a, **k: fake,
    )
    resp = client.post("/api/reconciliation/retry")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "retrying"
    assert isinstance(body["affected_count"], int) and body["affected_count"] >= 0
    assert fake.run_id is None


def test_retry_single_handles_error(monkeypatch):
    def failing_init(*args, **kwargs):
        raise RuntimeError("db connection lost")

    monkeypatch.setattr(
        "app.services.reconciliation_service.ReconciliationService",
        failing_init,
    )
    resp = client.post("/api/reconciliation/runs/recon-9/retry")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "failed"
    assert "RuntimeError" in body["reason_codes"]


def test_retry_batch_handles_error(monkeypatch):
    def failing_init(*args, **kwargs):
        raise RuntimeError("db connection lost")

    monkeypatch.setattr(
        "app.services.reconciliation_service.ReconciliationService",
        failing_init,
    )
    resp = client.post("/api/reconciliation/retry")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "failed"
    assert "RuntimeError" in body["reason_codes"]
