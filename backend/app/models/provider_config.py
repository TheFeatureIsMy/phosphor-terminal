"""Provider configuration persistence models.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §6.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
)

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ProviderConfig(Base):
    __tablename__ = "provider_configs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    # Identity
    category = Column(String, nullable=False, index=True)
    provider_name = Column(String, nullable=False, index=True)
    instance_name = Column(String, nullable=True)
    # Non-sensitive configuration
    config = Column(JSON, nullable=False, default=dict)
    # Encrypted credentials
    credentials_ct = Column(Text, nullable=True)
    credentials_fields = Column(JSON, nullable=True)
    # Status
    enabled = Column(Boolean, nullable=False, default=True)
    is_active = Column(Boolean, nullable=False, default=False)
    priority = Column(Integer, nullable=False, default=0)
    status = Column(String, nullable=False, default="unknown")
    credential_status = Column(String, nullable=False, default="missing")
    last_sync_at = Column(DateTime, nullable=True)
    last_error = Column(String, nullable=True)
    latency_ms = Column(Integer, nullable=True)
    rate_limit_remaining = Column(Integer, nullable=True)
    rate_limit_reset_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=_utcnow)
    updated_at = Column(DateTime, nullable=False, default=_utcnow, onupdate=_utcnow)

    __table_args__ = (
        CheckConstraint(
            "(category = 'llm' AND instance_name IS NOT NULL) OR "
            "(category != 'llm' AND instance_name IS NULL)",
            name="ck_instance_name_by_category",
        ),
        Index("ix_provider_config_cat_name", "category", "provider_name"),
        Index("ix_provider_config_enabled", "enabled"),
    )


class ProviderAuditLog(Base):
    __tablename__ = "provider_audit_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    provider_id = Column(
        Integer,
        ForeignKey("provider_configs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    action = Column(String, nullable=False)
    actor = Column(String, nullable=True)
    before_hash = Column(String, nullable=True)
    after_hash = Column(String, nullable=True)
    ip = Column(String, nullable=True)
    created_at = Column(DateTime, nullable=False, default=_utcnow, index=True)
