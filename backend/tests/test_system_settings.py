"""Tests for SystemSettingsService."""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.services.system_settings import SystemSettingsService


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    s = Session()
    yield s
    s.close()


def test_create_and_get(db):
    svc = SystemSettingsService()
    svc.upsert(db, "general.default_language", {"value": "zh-CN"}, "general", "alice")
    db.commit()
    row = svc.get(db, "general.default_language")
    assert row is not None
    assert row.value == {"value": "zh-CN"}
    assert row.category == "general"
    assert row.updated_by == "alice"


def test_update_existing(db):
    svc = SystemSettingsService()
    svc.upsert(db, "risk.max_single_loss", {"value": 5.0}, "risk")
    db.commit()
    svc.upsert(db, "risk.max_single_loss", {"value": 3.0}, "risk", "bob")
    db.commit()
    row = svc.get(db, "risk.max_single_loss")
    assert row.value == {"value": 3.0}
    assert row.updated_by == "bob"


def test_upsert_overwrites_existing(db):
    svc = SystemSettingsService()
    svc.upsert(db, "k1", {"v": 1}, "general")
    db.commit()
    svc.upsert(db, "k1", {"v": 2}, "general")
    db.commit()
    assert svc.get(db, "k1").value == {"v": 2}


def test_list_filtered_by_category(db):
    svc = SystemSettingsService()
    svc.upsert(db, "a", {"v": 1}, "general")
    svc.upsert(db, "b", {"v": 2}, "risk")
    svc.upsert(db, "c", {"v": 3}, "privacy")
    db.commit()
    assert len(svc.list(db)) == 3
    assert len(svc.list(db, category="risk")) == 1


def test_get_missing_returns_none(db):
    assert SystemSettingsService().get(db, "nope") is None


def test_delete(db):
    svc = SystemSettingsService()
    svc.upsert(db, "x", {"v": 1}, "general")
    db.commit()
    assert svc.delete(db, "x") is True
    db.commit()
    assert svc.get(db, "x") is None
    assert svc.delete(db, "x") is False
