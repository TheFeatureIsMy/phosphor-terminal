"""Azure OpenAI LLM provider. Real implementation (per-deployment, api-key header, POST probe)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class AzureOpenAIConfig(BaseModel):
    endpoint: str  # per-deployment URL e.g. https://myresource.openai.azure.com/openai/deployments/mydeployment
    deployment: str
    api_version: str = "2024-08-01-preview"
    model: str = "gpt-4o"
    timeout_s: float = Field(default=10.0)


class AzureOpenAIProvider:
    category = ProviderCategory.LLM
    provider_name = "azure_openai"
    is_multi_instance = True
    config_schema = AzureOpenAIConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        # Azure OpenAI: api-key header (NOT Bearer), POST chat/completions with 1-token body
        url = f"{cfg.endpoint.rstrip('/')}/chat/completions?api-version={cfg.api_version}"
        headers = {
            "api-key": api_key,
            "Content-Type": "application/json",
        }
        body = {
            "messages": [{"role": "user", "content": "ping"}],
            "max_tokens": 1,
        }
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(url, headers=headers, json=body) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=rl,
                        )
                    body_text = await resp.text()
                    err = f"HTTP {resp.status}: {body_text[:120]}"
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
