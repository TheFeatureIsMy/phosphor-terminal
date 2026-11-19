"""X (Twitter) social adapter. Stores a bearer token and probes /2/users/me."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class XConfig(BaseModel):
    base_url: str = Field(default="https://api.x.com")
    timeout_s: float = Field(default=10.0)


class XProvider:
    """Read-only X API v2 probe. Does not fetch timelines."""

    category = ProviderCategory.SOCIAL
    provider_name = "x"
    is_multi_instance = False
    config_schema = XConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        token = str(credentials.get("api_key") or "").strip()
        if not token:
            return HealthCheckResult(
                success=False, status=ProviderStatus.INACTIVE, error="missing bearer token",
            )
        url = f"{cfg.base_url.rstrip('/')}/2/users/me"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        headers = {"Authorization": f"Bearer {token}"}
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, headers=headers) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    body = await resp.text()
                    status = ProviderStatus.INACTIVE if resp.status in (401, 403) else ProviderStatus.ERROR
                    return HealthCheckResult(
                        success=False, status=status,
                        latency_ms=latency, error=f"HTTP {resp.status}: {body[:120]}",
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
