"""Discord notification adapter. Real implementation using webhook URL."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class DiscordConfig(BaseModel):
    timeout_s: float = Field(default=5.0)


class DiscordProvider:
    """Discord notification adapter (webhook model).

    Health check: HEAD the webhook URL. Discord returns 204 if the
    webhook is valid, 404 if it's been deleted.
    """

    category = ProviderCategory.NOTIFICATION
    provider_name = "discord"
    is_multi_instance = False
    config_schema = DiscordConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        webhook_url = credentials.get("webhook_url", "")
        if not webhook_url:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="webhook_url required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.head(webhook_url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 204:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    status = (
                        ProviderStatus.INACTIVE
                        if resp.status in (404,) else ProviderStatus.ERROR
                    )
                    return HealthCheckResult(
                        success=False, status=status,
                        latency_ms=latency,
                        error=f"HTTP {resp.status}",
                    )
        except Exception as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                latency_ms=None, error=str(exc)[:200],
            )

    async def fetch_rate_limit(self, credentials: dict, config: dict) -> RateLimitInfo | None:
        return None

    def mask_config(self, config: dict) -> dict:
        return dict(config)
