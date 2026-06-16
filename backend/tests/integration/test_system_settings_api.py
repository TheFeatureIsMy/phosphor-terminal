"""Integration tests for /api/admin/system-settings/*."""
import os
import tempfile

# Use a file-based SQLite DB so the module-level engine (used by get_db)
# and the test fixture share the same database across threads.
_tmp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp_db.close()
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp_db.name}?check_same_thread=False"

import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app.main import app
from app.models.system_settings import SystemSetting

# Patch init_db to a no-op -- the lifespan calls it.
import app.database as _db_mod
import app.main as _main_mod

_db_mod.init_db = lambda: None  # type: ignore[method-assign]
_main_mod.init_db = lambda: None  # type: ignore[method-assign]


@pytest.fixture(autouse=True)
def fernet_key(monkeypatch):
    monkeypatch.setenv("PULSEDESK_ENCRYPTION_KEY", Fernet.generate_key().decode())


@pytest.fixture
def db():
    from app.database import engine

    SystemSetting.__table__.create(engine, checkfirst=True)
    Session = sessionmaker(bind=engine)
    s = Session()
    yield s
    s.close()
    SystemSetting.__table__.drop(engine, checkfirst=True)


@pytest.fixture
def client(db):
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


def test_list_returns_empty(client):
    r = client.get("/api/admin/system-settings")
    assert r.status_code == 200
    assert r.json() == []


def test_upsert_and_get(client):
    r = client.put(
        "/api/admin/system-settings/risk.max_single_loss",
        json={"value": {"value": 5.0}, "category": "risk", "updated_by": "alice"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["key"] == "risk.max_single_loss"
    assert body["value"] == {"value": 5.0}
    assert body["category"] == "risk"

    r2 = client.get("/api/admin/system-settings/risk.max_single_loss")
    assert r2.status_code == 200
    assert r2.json()["value"] == {"value": 5.0}


def test_get_missing_returns_404(client):
    r = client.get("/api/admin/system-settings/nope.doesnt.exist")
    assert r.status_code == 404
    assert r.json()["detail"]["code"] == "not_found"


def test_update_existing(client):
    client.put(
        "/api/admin/system-settings/retention.logs_days",
        json={"value": {"value": 30}, "category": "retention"},
    )
    r = client.put(
        "/api/admin/system-settings/retention.logs_days",
        json={"value": {"value": 60}, "category": "retention", "updated_by": "bob"},
    )
    assert r.status_code == 200
    assert r.json()["value"] == {"value": 60}
    assert r.json()["updated_by"] == "bob"
