"""Generic Webhook notification adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class WebhookConfig(BaseModel):
    url: str
    timeout_s: float = Field(default=5.0)


class WebhookProvider:
    """Generic webhook notification adapter.

    Health check: POST {"ping": true} to the configured URL. Expect 2xx.
    Optional auth_header credential (e.g., "Bearer xyz").
    """

    category = ProviderCategory.NOTIFICATION
    provider_name = "webhook"
    is_multi_instance = False
    config_schema = WebhookConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        headers = {"Content-Type": "application/json"}
        auth_header = credentials.get("auth_header")
        if auth_header:
            headers["Authorization"] = auth_header
        body = {"ping": True}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(cfg.url, json=body, headers=headers) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if 200 <= resp.status < 300:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    return HealthCheckResult(
                        success=False, status=ProviderStatus.ERROR,
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
