"""Pydantic schemas for provider configuration.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §6.2-6.3.
"""
from __future__ import annotations

from datetime import datetime
from typing import Annotated, Literal, Union

from pydantic import BaseModel, ConfigDict, Field


class ProviderConfigBase(BaseModel):
    category: Literal[
        "llm", "cex", "dex", "notification",
        "market_data", "onchain", "social", "news",
    ]
    provider_name: str = Field(min_length=1, max_length=64)
    instance_name: str | None = Field(default=None, min_length=1, max_length=64)
    enabled: bool = True
    priority: int = Field(default=0, ge=0, le=10_000)
    config: dict = Field(default_factory=dict)
    # Plaintext credentials; encrypted by the service layer before storage.
    credentials: dict | None = None


class LLMConfig(ProviderConfigBase):
    category: Literal["llm"]
    instance_name: str  # required for LLM
    credentials: dict | None = None  # {api_key: str}


class CEXConfig(ProviderConfigBase):
    category: Literal["cex"]
    credentials: dict | None = None  # {api_key, api_secret, passphrase?}


class DeXConfig(ProviderConfigBase):
    category: Literal["dex"]
    credentials: dict | None = None  # {wallet_address, signature_provider}


class NotificationConfig(ProviderConfigBase):
    category: Literal["notification"]
    credentials: dict | None = None  # {bot_token, chat_id} for telegram


class MarketDataConfig(ProviderConfigBase):
    category: Literal["market_data"]
    credentials: dict | None = None  # {api_key}


class OnchainConfig(ProviderConfigBase):
    category: Literal["onchain"]
    credentials: dict | None = None  # {api_key}


class SocialConfig(ProviderConfigBase):
    category: Literal["social"]
    credentials: dict | None = None  # {api_key}


class NewsConfig(ProviderConfigBase):
    category: Literal["news"]
    credentials: dict | None = None  # {api_key}


ProviderConfigPayload = Annotated[
    Union[
        LLMConfig, CEXConfig, DeXConfig, NotificationConfig,
        MarketDataConfig, OnchainConfig, SocialConfig, NewsConfig,
    ],
    Field(discriminator="category"),
]


class ProviderConfigView(BaseModel):
    """Read-side view model. Never contains plaintext credentials."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    category: str
    provider_name: str
    instance_name: str | None
    enabled: bool
    is_active: bool
    priority: int
    status: str
    credential_status: str
    credential_fields: list[str]
    last_sync_at: datetime | None
    last_error: str | None
    latency_ms: int | None
    rate_limit_remaining: int | None
    rate_limit_reset_at: datetime | None
    config: dict
    updated_at: datetime


class HealthCheckResultSchema(BaseModel):
    success: bool
    status: str
    latency_ms: int | None
    error: str | None
    rate_limit: dict | None
    checked_at: datetime


class ProviderTestRequest(BaseModel):
    category: Literal[
        "llm", "cex", "dex", "notification",
        "market_data", "onchain", "social", "news",
    ]
    provider_name: str = Field(min_length=1, max_length=64)
    instance_name: str | None = None
    config: dict = Field(default_factory=dict)
    credentials: dict | None = None


class ProviderSummaryView(BaseModel):
    by_category: dict[str, int]
    total_active: int
    total_error: int
    total_disabled: int
    total_configured: int
    total: int
    checked_at: datetime
