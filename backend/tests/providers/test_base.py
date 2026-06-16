"""Tests for the ProviderAdapter Protocol and DTOs."""
from __future__ import annotations

import pytest
from pydantic import BaseModel, ValidationError

from app.services.providers.base import (
    CredentialStatus,
    HealthCheckResult,
    ProviderCategory,
    ProviderStatus,
    ProviderStubBase,
)


def test_provider_category_values():
    assert ProviderCategory.LLM.value == "llm"
    assert ProviderCategory.CEX.value == "cex"
    assert len(list(ProviderCategory)) == 8


def test_health_check_result_default_error_truncation():
    big_error = "x" * 500
    r = HealthCheckResult(
        success=False, status=ProviderStatus.ERROR,
        latency_ms=None, error=big_error, rate_limit=None,
        checked_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
    )
    assert r.error == big_error  # no automatic truncation in DTO


def test_stub_base_returns_not_implemented():
    class MyStub(ProviderStubBase):
        category = ProviderCategory.NEWS
        provider_name = "test_news"
        config_schema = BaseModel

    import asyncio
    result = asyncio.run(MyStub().test_connection({}, {}))
    assert result.success is False
    assert result.status == ProviderStatus.ERROR
    assert result.error == "not_implemented"


def test_stub_base_is_multi_instance_defaults_false():
    class MyStub(ProviderStubBase):
        category = ProviderCategory.CEX
        provider_name = "test_cex"
        config_schema = BaseModel

    assert MyStub.is_multi_instance is False
