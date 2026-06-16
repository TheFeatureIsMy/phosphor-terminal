"""Glassnode on-chain adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class GlassnodeConfig(BaseModel):
    base_url: str = Field(default="https://api.glassnode.com")
    timeout_s: float = Field(default=10.0)


class GlassnodeProvider:
    """Glassnode on-chain data adapter.

    Health check uses the cheapest public metric endpoint with API key
    in query. 401 (invalid key) maps to INACTIVE.
    """

    category = ProviderCategory.ONCHAIN
    provider_name = "glassnode"
    is_multi_instance = False
    config_schema = GlassnodeConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/v2/metrics/indicators/sopr?a=BTC&since=1700000000&api_key={api_key}"
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
                    status = (
                        ProviderStatus.INACTIVE
                        if resp.status in (401, 403) else ProviderStatus.ERROR
                    )
                    return HealthCheckResult(
                        success=False, status=status,
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
