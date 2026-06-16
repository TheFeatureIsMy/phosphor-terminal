"""Tests for ProviderHealthService — test orchestration and status derivation."""
from __future__ import annotations

from datetime import datetime, timezone

import pytest
from pydantic import BaseModel
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database.base import Base
from app.models.provider_config import ProviderConfig
from app.services.providers.base import (
    HealthCheckResult,
    ProviderCategory,
    ProviderStatus,
    ProviderStubBase,
)
from app.services.providers.health_service import ProviderHealthService
from app.services.providers.registry import ProviderRegistry


class _GoodProvider(ProviderStubBase):
    category = ProviderCategory.CEX
    provider_name = "good_cex"
    config_schema = BaseModel

    async def test_connection(self, credentials, config):
        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=42)


class _AuthFailProvider(ProviderStubBase):
    category = ProviderCategory.CEX
    provider_name = "auth_fail_cex"
    config_schema = BaseModel

    async def test_connection(self, credentials, config):
        return HealthCheckResult(success=False, status=ProviderStatus.ERROR, error="401 unauthorized")


class _RateLimitedProvider(ProviderStubBase):
    category = ProviderCategory.CEX
    provider_name = "rate_limited_cex"
    config_schema = BaseModel

    async def test_connection(self, credentials, config):
        return HealthCheckResult(
            success=True,
            status=ProviderStatus.RATE_LIMITED,
            latency_ms=10,
            rate_limit=__import__("app.services.providers.base", fromlist=["RateLimitInfo"]).RateLimitInfo(remaining=0, limit=100, source="header:x-ratelimit-remaining"),
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
def registry():
    reg = ProviderRegistry()
    reg.register(_GoodProvider)
    reg.register(_AuthFailProvider)
    reg.register(_RateLimitedProvider)
    return reg


@pytest.fixture
def svc(registry):
    return ProviderHealthService(registry=registry)


@pytest.mark.asyncio
async def test_test_provider_uses_registry(svc, db_session):
    row = ProviderConfig(
        category="cex", provider_name="good_cex", config={},
    )
    db_session.add(row); db_session.commit(); db_session.refresh(row)
    result = await svc.test_from_row(db_session, row)
    assert result.success is True
    assert result.status == "active"
    assert row.is_active is True
    assert row.status == "active"
    assert row.last_sync_at is not None
    assert row.latency_ms == 42


@pytest.mark.asyncio
async def test_auth_failure_records_error(svc, db_session):
    row = ProviderConfig(
        category="cex", provider_name="auth_fail_cex", config={},
    )
    db_session.add(row); db_session.commit(); db_session.refresh(row)
    result = await svc.test_from_row(db_session, row)
    assert result.success is False
    assert row.status == "inactive"
    assert "401" in row.last_error


@pytest.mark.asyncio
async def test_rate_limited_marks_status(svc, db_session):
    row = ProviderConfig(
        category="cex", provider_name="rate_limited_cex", config={},
    )
    db_session.add(row); db_session.commit(); db_session.refresh(row)
    await svc.test_from_row(db_session, row)
    assert row.status == "rate_limited"
    assert row.rate_limit_remaining == 0


@pytest.mark.asyncio
async def test_disabled_provider_skipped(svc, db_session):
    row = ProviderConfig(
        category="cex", provider_name="good_cex", config={},
        enabled=False,
    )
    db_session.add(row); db_session.commit(); db_session.refresh(row)
    result = await svc.test_from_row(db_session, row)
    assert result.status == ProviderStatus.DISABLED
    assert row.status == "disabled"


def test_status_derivation_table():
    from app.services.providers.health_service import _derive_status
    from app.services.providers.base import RateLimitInfo
    now = datetime.now(timezone.utc)
    # No rate limit + success
    r = HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=10, error=None, rate_limit=None, checked_at=now)
    assert _derive_status(r, enabled=True, last_sync=now) == "active"
    # Rate limited (remaining=0)
    r = HealthCheckResult(
        success=True, status=ProviderStatus.RATE_LIMITED, latency_ms=10, error=None,
        rate_limit=RateLimitInfo(remaining=0),
        checked_at=now,
    )
    assert _derive_status(r, enabled=True, last_sync=now) == "rate_limited"
    # Disabled
    assert _derive_status(r, enabled=False, last_sync=now) == "disabled"
    # Old sync -> unknown
    old = datetime(2000, 1, 1, tzinfo=timezone.utc)
    assert _derive_status(r, enabled=True, last_sync=old) == "unknown"
