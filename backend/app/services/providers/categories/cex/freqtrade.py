"""Freqtrade CEX adapter. Pings the running Freqtrade instance."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class FreqtradeConfig(BaseModel):
    url: str = Field(default="http://localhost:8080")
    username: str = Field(default="freqtrade")
    password: str = Field(default="freqtrade")
    timeout_s: float = Field(default=5.0)


class FreqtradeProvider:
    category = ProviderCategory.CEX
    provider_name = "freqtrade"
    is_multi_instance = False
    config_schema = FreqtradeConfig

    def __init__(self, client_factory=None) -> None:
        """client_factory is injectable for tests; defaults to FreqtradeClient."""
        self._client_factory = client_factory

    async def test_connection(self, credentials, config):
        cfg = self.config_schema.model_validate(config)
        try:
            if self._client_factory is not None:
                client = self._client_factory(
                    base_url=cfg.url, username=cfg.username, password=cfg.password,
                )
            else:
                from app.services.freqtrade_client import FreqtradeClient
                client = FreqtradeClient(
                    base_url=cfg.url, username=cfg.username, password=cfg.password,
                )
            ok = await client.ping()
            if ok:
                return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=None, rate_limit=None)
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error="ping returned False")
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
