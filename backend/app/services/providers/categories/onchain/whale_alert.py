"""Whale Alert on-chain adapter. Real implementation (public status endpoint)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class WhaleAlertConfig(BaseModel):
    base_url: str = Field(default="https://api.whale-alert.io")
    timeout_s: float = Field(default=10.0)


class WhaleAlertProvider:
    """Whale Alert on-chain data adapter. Public /v1/status endpoint."""

    category = ProviderCategory.ONCHAIN
    provider_name = "whale_alert"
    is_multi_instance = False
    config_schema = WhaleAlertConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/v1/status"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    body = await resp.text()
                    err = f"HTTP {resp.status}: {body[:120]}"
                    return HealthCheckResult(
                        success=False, status=ProviderStatus.ERROR,
                        latency_ms=latency, error=err,
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
