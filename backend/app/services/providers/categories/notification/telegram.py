"""Telegram notification provider. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class TelegramConfig(BaseModel):
    dry_run: bool = Field(default=True)
    timeout_s: float = Field(default=10.0)


class TelegramProvider:
    category = ProviderCategory.NOTIFICATION
    provider_name = "telegram"
    is_multi_instance = False
    config_schema = TelegramConfig

    async def test_connection(self, credentials, config):
        bot_token = credentials.get("bot_token", "")
        chat_id = credentials.get("chat_id", "")
        if not bot_token or not chat_id:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="bot_token and chat_id required",
                latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        if cfg.dry_run:
            return HealthCheckResult(
                success=True, status=ProviderStatus.ACTIVE,
                latency_ms=None, rate_limit=None,
            )
        url = f"https://api.telegram.org/bot{bot_token}/getMe"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
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
