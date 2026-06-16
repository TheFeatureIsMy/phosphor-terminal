"""Tests for ProviderConfigService — CRUD, encryption, uniqueness."""
from __future__ import annotations

import json

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database.base import Base
from app.models.provider_config import ProviderConfig
from app.services.providers.base import ProviderCategory
from app.services.providers.config_service import (
    DuplicateProviderError,
    ProviderConfigService,
)


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    s = Session()
    yield s
    s.close()


@pytest.fixture
def crypto(monkeypatch):
    from cryptography.fernet import Fernet
    monkeypatch.setenv("PULSEDESK_ENCRYPTION_KEY", Fernet.generate_key().decode())
    from app.services import crypto_service
    import importlib
    importlib.reload(crypto_service)
    return crypto_service.CryptoService()


@pytest.fixture
def svc(crypto):
    return ProviderConfigService(crypto=crypto)


def test_create_llm_persists_credentials_encrypted(svc, db_session):
    payload = {
        "category": "llm",
        "provider_name": "openai",
        "instance_name": "dev",
        "credentials": {"api_key": "sk-abc-12345"},
        "config": {"model": "gpt-4o"},
    }
    row = svc.upsert(db_session, payload)
    db_session.commit()
    assert row.id is not None
    assert row.credentials_ct != "sk-abc-12345"
    assert "sk-abc" not in (row.credentials_ct or "")
    assert row.credentials_fields == ["api_key"]


def test_view_model_does_not_leak_plaintext(svc, db_session):
    payload = {
        "category": "llm",
        "provider_name": "openai",
        "instance_name": "prod",
        "credentials": {"api_key": "sk-abc-12345"},
    }
    svc.upsert(db_session, payload)
    db_session.commit()
    view = svc.to_view(db_session.query(ProviderConfig).first())
    assert "sk-abc" not in json.dumps(view.model_dump(mode="json"))
    assert view.credential_status == "configured"
    assert view.credentials_fields == ["api_key"]


def test_duplicate_llm_instance_raises(svc, db_session):
    payload = {
        "category": "llm",
        "provider_name": "openai",
        "instance_name": "dev",
    }
    svc.upsert(db_session, payload)
    db_session.commit()
    try:
        svc.upsert(db_session, payload)
    except DuplicateProviderError:
        pass
    else:
        raise AssertionError("expected DuplicateProviderError for duplicate LLM instance")


def test_duplicate_single_instance_raises(svc, db_session):
    payload = {
        "category": "cex",
        "provider_name": "binance",
    }
    svc.upsert(db_session, payload)
    db_session.commit()
    try:
        svc.upsert(db_session, payload)
    except DuplicateProviderError:
        pass
    else:
        raise AssertionError("expected DuplicateProviderError for duplicate CEX")


def test_llm_without_instance_name_raises(svc, db_session):
    from pydantic import ValidationError
    try:
        svc.upsert(db_session, {
            "category": "llm",
            "provider_name": "openai",
        })
    except ValidationError:
        pass
    else:
        raise AssertionError("expected ValidationError for LLM without instance_name")


def test_non_llm_with_instance_name_raises(svc, db_session):
    from sqlalchemy.exc import IntegrityError
    payload = {
        "category": "cex",
        "provider_name": "binance",
        "instance_name": "should_not_be_set",
    }
    try:
        svc.upsert(db_session, payload)
    except IntegrityError:
        db_session.rollback()
    else:
        raise AssertionError("expected IntegrityError for non-LLM with instance_name")


def test_enable_disable_toggle(svc, db_session):
    payload = {"category": "cex", "provider_name": "binance"}
    row = svc.upsert(db_session, payload)
    db_session.commit()
    assert row.enabled is True
    svc.set_enabled(db_session, row.id, False)
    db_session.commit()
    assert svc.get(db_session, row.id).enabled is False


def test_get_unknown_returns_none(svc, db_session):
    assert svc.get(db_session, 999) is None
