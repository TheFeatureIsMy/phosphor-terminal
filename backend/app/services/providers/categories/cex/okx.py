"""OKX CEX adapter. Real implementation using public time endpoint."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class OKXConfig(BaseModel):
    base_url: str = Field(default="https://www.okx.com")
    timeout_s: float = Field(default=10.0)


class OKXProvider:
    """OKX CEX adapter.

    Health check uses the public /api/v5/public/time endpoint, which does
    NOT require authentication. For future private-endpoint calls
    (orders, balances), the credentials dict holds api_key / secret /
    passphrase; HMAC SHA256 signing would be added in that sub-project.
    """

    category = ProviderCategory.CEX
    provider_name = "okx"
    is_multi_instance = False
    config_schema = OKXConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        # credentials are accepted but not used for the public /time probe
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v5/public/time"
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
