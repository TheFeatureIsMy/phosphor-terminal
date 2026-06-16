"""ProviderAdapter Protocol, enums, DTOs, and stub base class.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §7.1.
"""
from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Any, Protocol, runtime_checkable

from pydantic import BaseModel, Field


class ProviderCategory(str, Enum):
    LLM = "llm"
    CEX = "cex"
    DEX = "dex"
    NOTIFICATION = "notification"
    MARKET_DATA = "market_data"
    ONCHAIN = "onchain"
    SOCIAL = "social"
    NEWS = "news"


class ProviderStatus(str, Enum):
    UNKNOWN = "unknown"
    ACTIVE = "active"
    INACTIVE = "inactive"
    ERROR = "error"
    RATE_LIMITED = "rate_limited"
    DISABLED = "disabled"


class CredentialStatus(str, Enum):
    MISSING = "missing"
    CONFIGURED = "configured"
    EXPIRED = "expired"
    INVALID = "invalid"


class RateLimitInfo(BaseModel):
    remaining: int | None = None
    limit: int | None = None
    reset_at: datetime | None = None
    retry_after_s: int | None = None
    source: str = ""


class HealthCheckResult(BaseModel):
    success: bool
    status: ProviderStatus
    latency_ms: int | None = None
    error: str | None = None
    rate_limit: RateLimitInfo | None = None
    checked_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


@runtime_checkable
class ProviderAdapter(Protocol):
    """Every provider must implement this Protocol."""

    category: ProviderCategory
    provider_name: str
    is_multi_instance: bool
    config_schema: type[BaseModel]

    async def test_connection(
        self, credentials: dict, config: dict
    ) -> HealthCheckResult: ...

    async def fetch_rate_limit(
        self, credentials: dict, config: dict
    ) -> RateLimitInfo | None: ...

    def mask_config(self, config: dict) -> dict: ...


class ProviderStubBase:
    """DRY base for stub providers. Returns not_implemented on test."""

    category: ProviderCategory
    provider_name: str
    is_multi_instance: bool = False
    config_schema: type[BaseModel] = BaseModel

    async def test_connection(
        self, credentials: dict, config: dict
    ) -> HealthCheckResult:
        return HealthCheckResult(
            success=False,
            status=ProviderStatus.ERROR,
            error="not_implemented",
        )

    async def fetch_rate_limit(
        self, credentials: dict, config: dict
    ) -> RateLimitInfo | None:
        return None

    def mask_config(self, config: dict) -> dict:
        return dict(config)
