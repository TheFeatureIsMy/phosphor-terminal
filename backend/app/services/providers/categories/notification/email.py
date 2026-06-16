"""Email (SMTP) notification adapter. Real implementation using smtplib."""
from __future__ import annotations

import smtplib

from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class EmailConfig(BaseModel):
    host: str
    port: int = 587
    use_tls: bool = True
    timeout_s: float = Field(default=5.0)


class EmailProvider:
    """Email (SMTP) notification adapter.

    Health check: open SMTP connection, optionally start TLS, login
    with credentials, quit. Any failure -> ERROR or INACTIVE.
    """

    category = ProviderCategory.NOTIFICATION
    provider_name = "email"
    is_multi_instance = False
    config_schema = EmailConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        username = credentials.get("username", "")
        password = credentials.get("password", "")
        cfg = self.config_schema.model_validate(config)
        try:
            with smtplib.SMTP(cfg.host, cfg.port, timeout=cfg.timeout_s) as smtp:
                if cfg.use_tls:
                    smtp.starttls()
                smtp.login(username, password)
            return HealthCheckResult(
                success=True, status=ProviderStatus.ACTIVE,
                latency_ms=None, rate_limit=None,
            )
        except smtplib.SMTPAuthenticationError as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.INACTIVE,
                error=f"SMTP auth failed: {exc}", latency_ms=None,
            )
        except Exception as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error=str(exc)[:200], latency_ms=None,
            )

    async def fetch_rate_limit(self, credentials: dict, config: dict) -> RateLimitInfo | None:
        return None

    def mask_config(self, config: dict) -> dict:
        return dict(config)
