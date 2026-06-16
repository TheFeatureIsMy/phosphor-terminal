"""ProviderHealthService — orchestrates connection tests and status derivation."""
from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.provider_config import ProviderConfig
from app.services.providers.base import (
    HealthCheckResult,
    ProviderStatus,
)
from app.services.providers.config_service import ProviderConfigService
from app.services.providers.registry import ProviderRegistry

logger = logging.getLogger(__name__)

# 24 hours — providers not tested this long are considered unknown.
UNKNOWN_AFTER_SECONDS = 24 * 3600


def _derive_status(
    result: HealthCheckResult,
    enabled: bool,
    last_sync: datetime | None,
    now: datetime | None = None,
) -> str:
    """Pure function: turn (test result, enabled, last_sync) into a status string."""
    if not enabled:
        return ProviderStatus.DISABLED.value
    if last_sync is None:
        return ProviderStatus.UNKNOWN.value
    now = now or datetime.now(timezone.utc)
    age = (now - last_sync).total_seconds()
    if age > UNKNOWN_AFTER_SECONDS:
        return ProviderStatus.UNKNOWN.value
    if not result.success:
        err = (result.error or "").lower()
        if "401" in err or "403" in err or "expired" in err or "invalid" in err:
            return ProviderStatus.INACTIVE.value
        return ProviderStatus.ERROR.value
    if result.rate_limit and result.rate_limit.remaining == 0:
        return ProviderStatus.RATE_LIMITED.value
    return ProviderStatus.ACTIVE.value


class ProviderHealthService:
    def __init__(
        self,
        registry: ProviderRegistry,
        config_service: ProviderConfigService | None = None,
    ) -> None:
        self._registry = registry
        self._config_service = config_service or ProviderConfigService()

    async def test_from_row(
        self,
        db: Session,
        row: ProviderConfig,
    ) -> HealthCheckResult:
        """Run a connection test using the row's stored config and credentials."""
        from app.services.providers.base import ProviderCategory

        if not row.enabled:
            now = datetime.now(timezone.utc)
            row.status = ProviderStatus.DISABLED.value
            row.last_sync_at = now
            return HealthCheckResult(
                success=False, status=ProviderStatus.DISABLED,
                latency_ms=None, error="disabled", rate_limit=None, checked_at=now,
            )

        try:
            category = ProviderCategory(row.category)
        except ValueError:
            return self._record_error(row, f"unknown category: {row.category}")

        if not self._registry.has(category, row.provider_name):
            return self._record_error(row, f"unknown provider: {row.provider_name}")

        try:
            adapter = self._registry.get(category, row.provider_name)
        except KeyError as e:
            return self._record_error(row, str(e))

        creds = self._config_service.decrypt_credentials(row) or {}
        config = row.config or {}

        try:
            result: HealthCheckResult = await adapter.test_connection(creds, config)
        except Exception as exc:
            return self._record_error(row, f"adapter exception: {str(exc)[:200]}")

        now = datetime.now(timezone.utc)
        status = _derive_status(result, enabled=row.enabled, last_sync=now)
        row.status = status
        row.is_active = (status == ProviderStatus.ACTIVE.value)
        row.last_sync_at = now
        row.latency_ms = result.latency_ms
        row.last_error = (result.error or "")[:200] if not result.success else None
        if result.rate_limit:
            row.rate_limit_remaining = result.rate_limit.remaining
            row.rate_limit_reset_at = result.rate_limit.reset_at
        db.flush()
        return result

    async def test_ephemeral(
        self,
        category: str,
        provider_name: str,
        credentials: dict,
        config: dict,
    ) -> HealthCheckResult:
        """Run a connection test without touching the DB. For paste-then-test UX."""
        from app.services.providers.base import ProviderCategory

        try:
            cat = ProviderCategory(category)
        except ValueError:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error=f"unknown category: {category}", latency_ms=None, rate_limit=None,
                checked_at=datetime.now(timezone.utc),
            )
        if not self._registry.has(cat, provider_name):
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error=f"unknown provider: {provider_name}", latency_ms=None, rate_limit=None,
                checked_at=datetime.now(timezone.utc),
            )
        adapter = self._registry.get(cat, provider_name)
        try:
            return await adapter.test_connection(credentials, config)
        except Exception as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error=str(exc)[:200], latency_ms=None, rate_limit=None,
                checked_at=datetime.now(timezone.utc),
            )

    def _record_error(self, row: ProviderConfig, message: str) -> HealthCheckResult:
        now = datetime.now(timezone.utc)
        row.last_error = message[:200]
        row.last_sync_at = now
        row.status = ProviderStatus.ERROR.value
        row.is_active = False
        return HealthCheckResult(
            success=False, status=ProviderStatus.ERROR,
            latency_ms=None, error=message, rate_limit=None, checked_at=now,
        )
