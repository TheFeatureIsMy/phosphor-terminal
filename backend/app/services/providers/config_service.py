"""ProviderConfigService — DB CRUD with encryption and uniqueness."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.models.provider_config import ProviderConfig
from app.schemas.provider_config import (
    LLMConfig,
    ProviderConfigView,
)
from app.services.crypto_service import CryptoService
from app.services.providers.base import ProviderCategory
from app.services.providers.crypto import ProviderSecretCodec


class DuplicateProviderError(ValueError):
    """Raised on (category, provider_name, instance_name) uniqueness violation."""


class ProviderConfigService:
    def __init__(self, crypto: CryptoService | None = None) -> None:
        self._crypto = crypto or CryptoService()
        self._codec = ProviderSecretCodec(self._crypto)

    def get(self, db: Session, row_id: int) -> ProviderConfig | None:
        return db.query(ProviderConfig).filter(ProviderConfig.id == row_id).first()

    def get_by_identity(
        self,
        db: Session,
        category: str,
        provider_name: str,
        instance_name: str | None = None,
    ) -> ProviderConfig | None:
        q = db.query(ProviderConfig).filter(
            ProviderConfig.category == category,
            ProviderConfig.provider_name == provider_name,
        )
        if category == ProviderCategory.LLM.value:
            q = q.filter(ProviderConfig.instance_name == instance_name)
        else:
            q = q.filter(ProviderConfig.instance_name.is_(None))
        return q.first()

    def list(
        self,
        db: Session,
        category: str | None = None,
        enabled_only: bool = False,
    ) -> list[ProviderConfig]:
        q = db.query(ProviderConfig)
        if category:
            q = q.filter(ProviderConfig.category == category)
        if enabled_only:
            q = q.filter(ProviderConfig.enabled.is_(True))
        return q.order_by(ProviderConfig.category, ProviderConfig.provider_name).all()

    def upsert(self, db: Session, payload: dict[str, Any]) -> ProviderConfig:
        """Create or update. Pydantic discriminated union validates shape."""
        validated = self._validate_payload(payload)

        category = validated.category
        provider_name = validated.provider_name
        instance_name = validated.instance_name
        credentials_dict = validated.credentials

        existing = self.get_by_identity(db, category, provider_name, instance_name)
        if existing is not None:
            raise DuplicateProviderError(
                f"Provider already exists: {category}/{provider_name}"
                + (f"/{instance_name}" if instance_name else "")
            )

        ciphertext = self._codec.encrypt_dict(credentials_dict)
        fields = self._codec.field_names(credentials_dict)
        cred_status = "configured" if credentials_dict else "missing"

        row = ProviderConfig(
            category=category,
            provider_name=provider_name,
            instance_name=instance_name,
            config=validated.config,
            credentials_ct=ciphertext,
            credentials_fields=fields,
            enabled=validated.enabled,
            priority=validated.priority,
            status="unknown",
            credential_status=cred_status,
        )
        db.add(row)
        db.flush()
        return row

    def delete(self, db: Session, row_id: int) -> bool:
        row = self.get(db, row_id)
        if row is None:
            return False
        db.delete(row)
        db.flush()
        return True

    def set_enabled(self, db: Session, row_id: int, enabled: bool) -> ProviderConfig | None:
        row = self.get(db, row_id)
        if row is None:
            return None
        row.enabled = enabled
        if not enabled:
            row.status = "disabled"
        db.flush()
        return row

    def decrypt_credentials(self, row: ProviderConfig) -> dict | None:
        return self._codec.decrypt_dict(row.credentials_ct)

    def to_view(self, row: ProviderConfig) -> ProviderConfigView:
        return ProviderConfigView(
            id=row.id,
            category=row.category,
            provider_name=row.provider_name,
            instance_name=row.instance_name,
            enabled=row.enabled,
            is_active=row.is_active,
            priority=row.priority,
            status=row.status,
            credential_status=row.credential_status,
            credentials_fields=row.credentials_fields or [],
            last_sync_at=row.last_sync_at,
            last_error=row.last_error,
            latency_ms=row.latency_ms,
            rate_limit_remaining=row.rate_limit_remaining,
            rate_limit_reset_at=row.rate_limit_reset_at,
            config=row.config or {},
            updated_at=row.updated_at or datetime.now(timezone.utc),
        )

    @staticmethod
    def _validate_payload(payload: dict[str, Any]) -> Any:
        category = payload.get("category")
        if category == ProviderCategory.LLM.value:
            return LLMConfig.model_validate(payload)
        from app.schemas.provider_config import (
            CEXConfig, DeXConfig, NotificationConfig, MarketDataConfig,
            OnchainConfig, SocialConfig, NewsConfig,
        )
        mapping = {
            "cex": CEXConfig, "dex": DeXConfig, "notification": NotificationConfig,
            "market_data": MarketDataConfig, "onchain": OnchainConfig,
            "social": SocialConfig, "news": NewsConfig,
        }
        if category not in mapping:
            raise ValueError(f"Unknown category: {category}")
        return mapping[category].model_validate(payload)
