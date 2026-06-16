"""Anthropic LLM provider adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class AnthropicConfig(BaseModel):
    model: str = Field(default="claude-sonnet-4-20250514")
    timeout_s: float = Field(default=10.0)


class AnthropicProvider:
    category = ProviderCategory.LLM
    provider_name = "anthropic"
    is_multi_instance = True
    config_schema = AnthropicConfig

    async def test_connection(self, credentials, config):
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, error="api_key required", latency_ms=None, rate_limit=None)
        cfg = self.config_schema.model_validate(config)
        url = "https://api.anthropic.com/v1/messages"
        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
        body = {"model": cfg.model, "max_tokens": 1, "messages": [{"role": "user", "content": "ping"}]}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(url, headers=headers, json=body) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status in (200, 400):
                        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=latency, rate_limit=None)
                    text = await resp.text()
                    status = ProviderStatus.INACTIVE if resp.status in (401, 403) else ProviderStatus.ERROR
                    return HealthCheckResult(success=False, status=status, latency_ms=latency, error=f"HTTP {resp.status}: {text[:120]}")
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
