"""Ollama local LLM provider adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class OllamaConfig(BaseModel):
    base_url: str = Field(default="http://localhost:11434")
    model: str = Field(default="qwen2.5:7b")
    timeout_s: float = Field(default=5.0)


class OllamaProvider:
    category = ProviderCategory.LLM
    provider_name = "ollama"
    is_multi_instance = True
    config_schema = OllamaConfig

    async def test_connection(self, credentials, config):
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/tags"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
                        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=latency, rate_limit=None)
                    text = await resp.text()
                    return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=latency, error=f"HTTP {resp.status}: {text[:120]}")
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
