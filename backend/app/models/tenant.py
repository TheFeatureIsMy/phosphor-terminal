"""Tenant and membership models (multi-tenant SaaS foundation)."""
from datetime import datetime, timezone

from sqlalchemy import (
    JSON, Boolean, Column, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint,
)

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Tenant(Base):
    __tablename__ = "tenants"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(120), nullable=False)
    slug = Column(String(140), unique=True, nullable=False, index=True)
    status = Column(String(20), nullable=False, default="active")
    plan = Column(String(20), nullable=False, default="free")
    created_at = Column(DateTime, default=_utcnow, nullable=False)


class Membership(Base):
    __tablename__ = "memberships"
    __table_args__ = (
        UniqueConstraint("user_id", "tenant_id", name="uq_membership_user_tenant"),
    )

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    tenant_id = Column(
        Integer, ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    role = Column(String(20), nullable=False, default="owner")
    created_at = Column(DateTime, default=_utcnow, nullable=False)


class TenantExecutionProfile(Base):
    """Per-tenant execution runtime endpoint.

    ``mode``:
      - disabled: execution APIs are closed for the tenant
      - dedicated: route to ``freqtrade_url`` (separate runtime)
    Superusers keep using the platform-shared runtime.
    """
    __tablename__ = "tenant_execution_profiles"

    tenant_id = Column(
        Integer, ForeignKey("tenants.id", ondelete="CASCADE"), primary_key=True,
    )
    mode = Column(String(24), nullable=False, default="disabled")
    freqtrade_url = Column(String(256), nullable=True)
    api_username = Column(String(128), nullable=True)
    api_password_ct = Column(String(1024), nullable=True)
    exchange_key_ct = Column(String(2048), nullable=True)
    exchange_secret_ct = Column(String(2048), nullable=True)
    enabled = Column(Boolean, nullable=False, default=False)
    runtime_status = Column(String(24), nullable=False, default="unknown")
    last_health_at = Column(DateTime, nullable=True)
    last_error = Column(Text, nullable=True)
    max_open_trades = Column(Integer, nullable=False, default=2)
    created_at = Column(DateTime, default=_utcnow, nullable=False)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow, nullable=False)


class DeviceSession(Base):
    """Login session attached to an access/refresh token (`sid` claim)."""
    __tablename__ = "device_sessions"

    id = Column(String(36), primary_key=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True,
    )
    tenant_id = Column(
        Integer, ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True,
    )
    device_name = Column(String(128), nullable=True)
    user_agent = Column(String(512), nullable=True)
    ip_address = Column(String(64), nullable=True)
    created_at = Column(DateTime, default=_utcnow, nullable=False)
    last_seen_at = Column(DateTime, default=_utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)


class TenantInvite(Base):
    """One-time invite link for joining a tenant (email delivery optional)."""
    __tablename__ = "tenant_invites"

    id = Column(String(36), primary_key=True)
    tenant_id = Column(
        Integer, ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True,
    )
    email = Column(String(320), nullable=False, index=True)
    role = Column(String(20), nullable=False, default="viewer")
    token_hash = Column(String(64), nullable=False, unique=True, index=True)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=_utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    accepted_at = Column(DateTime, nullable=True)


class TenantAuditLog(Base):
    __tablename__ = "tenant_audit_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    tenant_id = Column(
        Integer, ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    actor_user_id = Column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    action = Column(String(80), nullable=False, index=True)
    detail = Column(JSON, default=dict)
    created_at = Column(DateTime, default=_utcnow, index=True)


class TenantSubscription(Base):
    __tablename__ = "tenant_subscriptions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    tenant_id = Column(
        Integer, ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False, unique=True, index=True,
    )
    plan = Column(String(20), nullable=False, default="free")
    status = Column(String(20), nullable=False, default="active")
    provider = Column(String(40), nullable=False, default="manual")
    external_id = Column(String(120), nullable=True)
    current_period_end = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class BillingEvent(Base):
    __tablename__ = "billing_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    tenant_id = Column(
        Integer, ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    provider = Column(String(40), nullable=False)
    event_id = Column(String(160), nullable=False)
    event_type = Column(String(80), nullable=True)
    received_at = Column(DateTime, default=_utcnow)
    __table_args__ = (UniqueConstraint("provider", "event_id", name="uq_billing_event"),)
