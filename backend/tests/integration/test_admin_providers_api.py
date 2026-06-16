"""End-to-end tests for /api/admin/providers/* using FastAPI TestClient."""
from __future__ import annotations

import os
import tempfile

# Use a file-based SQLite DB so the module-level engine (used by get_db)
# and the test fixture share the same database across threads.
_tmp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp_db.close()
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp_db.name}?check_same_thread=False"
# Disable the provider health scheduler during tests.
os.environ["PROVIDER_HEALTH_INTERVAL_S"] = "0"

import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app.main import app

# Patch init_db to a no-op -- the lifespan calls it, but we create only
# the provider tables ourselves to avoid JSONB column failures on SQLite.
import app.database as _db_mod
import app.main as _main_mod

_db_mod.init_db = lambda: None  # type: ignore[method-assign]
_main_mod.init_db = lambda: None  # type: ignore[method-assign]

# Populate the provider registry so /categories and /create work.
from app.services.providers.categories import register_all

register_all()


@pytest.fixture(autouse=True)
def fernet_key(monkeypatch):
    key = Fernet.generate_key().decode()
    monkeypatch.setenv("PULSEDESK_ENCRYPTION_KEY", key)
    import importlib
    from app.services import crypto_service
    importlib.reload(crypto_service)
    yield key


@pytest.fixture
def db_session():
    """Create provider tables on the module-level engine shared with get_db."""
    from app.database import engine
    from app.models.provider_config import ProviderConfig, ProviderAuditLog
    ProviderConfig.__table__.create(engine, checkfirst=True)
    ProviderAuditLog.__table__.create(engine, checkfirst=True)
    Session = sessionmaker(bind=engine)
    s = Session()
    yield s
    s.close()
    # Drop tables between tests for isolation.
    ProviderAuditLog.__table__.drop(engine, checkfirst=True)
    ProviderConfig.__table__.drop(engine, checkfirst=True)


@pytest.fixture
def client(db_session):
    def _override():
        from app.database import SessionLocal
        db = SessionLocal()
        try:
            yield db
        finally:
            db.close()
    app.dependency_overrides[get_db] = _override
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def test_categories_endpoint_lists_registered(client):
    r = client.get("/api/admin/providers/categories")
    assert r.status_code == 200
    cats = r.json()["categories"]
    assert "llm" in cats
    assert "cex" in cats
    assert "openai" in [p["name"] for p in cats["llm"]]
    assert "binance" in [p["name"] for p in cats["cex"]]


def test_create_persists_credentials_encrypted(client, db_session):
    r = client.post("/api/admin/providers", json={
        "category": "llm",
        "provider_name": "openai",
        "instance_name": "test",
        "credentials": {"api_key": "sk-plaintext-12345"},
        "config": {"model": "gpt-4o"},
    })
    assert r.status_code == 201, r.text
    body = r.json()
    assert "sk-plaintext" not in str(body)
    assert body["credentials_fields"] == ["api_key"]
    assert body["credential_status"] == "configured"

    from app.models.provider_config import ProviderConfig
    row = db_session.query(ProviderConfig).first()
    assert "sk-plaintext" not in (row.credentials_ct or "")


def test_get_does_not_leak_plaintext(client):
    client.post("/api/admin/providers", json={
        "category": "llm", "provider_name": "openai", "instance_name": "x",
        "credentials": {"api_key": "sk-secret-9999"},
    })
    r = client.get("/api/admin/providers")
    assert r.status_code == 200
    assert "sk-secret" not in str(r.json())


def test_duplicate_single_instance_returns_409(client):
    p = {"category": "cex", "provider_name": "binance"}
    r1 = client.post("/api/admin/providers", json=p)
    assert r1.status_code == 201
    r2 = client.post("/api/admin/providers", json=p)
    assert r2.status_code == 409
    assert r2.json()["detail"]["code"] == "duplicate"


def test_duplicate_llm_instance_returns_409(client):
    p = {"category": "llm", "provider_name": "openai", "instance_name": "x"}
    assert client.post("/api/admin/providers", json=p).status_code == 201
    assert client.post("/api/admin/providers", json=p).status_code == 409


def test_unknown_provider_returns_400(client):
    r = client.post("/api/admin/providers", json={"category": "cex", "provider_name": "nope"})
    assert r.status_code == 400
    assert r.json()["detail"]["code"] == "unknown_provider"


def test_enable_disable_toggle(client):
    r = client.post("/api/admin/providers", json={"category": "cex", "provider_name": "binance"})
    pid = r.json()["id"]
    r2 = client.post(f"/api/admin/providers/{pid}/disable")
    assert r2.status_code == 200
    assert r2.json()["enabled"] is False
    r3 = client.post(f"/api/admin/providers/{pid}/enable")
    assert r3.json()["enabled"] is True


def test_audit_log_records_actions(client):
    r = client.post("/api/admin/providers", json={"category": "cex", "provider_name": "binance"})
    pid = r.json()["id"]
    client.post(f"/api/admin/providers/{pid}/disable")
    client.post(f"/api/admin/providers/{pid}/enable")
    audit = client.get(f"/api/admin/providers/{pid}/audit-log").json()
    actions = [a["action"] for a in audit]
    assert "create" in actions
    assert "disable" in actions
    assert "enable" in actions


def test_rotate_returns_501(client):
    r = client.post("/api/admin/providers", json={"category": "cex", "provider_name": "binance"})
    pid = r.json()["id"]
    r2 = client.post(f"/api/admin/providers/{pid}/rotate-credentials")
    assert r2.status_code == 501
