"""Binance CEX adapter. Real implementation using public API."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class BinanceConfig(BaseModel):
    base_url: str = Field(default="https://api.binance.com")
    timeout_s: float = Field(default=10.0)


class BinanceProvider:
    category = ProviderCategory.CEX
    provider_name = "binance"
    is_multi_instance = False
    config_schema = BinanceConfig

    async def test_connection(self, credentials, config):
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v3/ping"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=latency, rate_limit=rl)
                    text = await resp.text()
                    return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=latency, error=f"HTTP {resp.status}: {text[:120]}", rate_limit=rl)
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
