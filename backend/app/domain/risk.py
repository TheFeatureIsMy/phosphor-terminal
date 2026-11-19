"""Risk Engine — v2.5 ERD §6"""
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint,
    event, func, select, text,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import text, func, JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class RiskPolicy(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "risk_policies"

    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    policy_type: Mapped[str] = mapped_column(String(24), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="draft")


class RiskPolicyVersion(UUIDMixin, Base):
    __tablename__ = "risk_policy_versions"

    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    risk_policy_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("risk_policies.id"), nullable=False,
    )
    version_no: Mapped[int] = mapped_column(Integer, nullable=False)
    policy_json: Mapped[dict] = mapped_column(JSONB, nullable=False)
    policy_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="draft")
    created_by: Mapped[str] = mapped_column(String(128), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (UniqueConstraint("risk_policy_id", "version_no"),)


class CapitalPool(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "capital_pools"

    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    pool_type: Mapped[str] = mapped_column(String(24), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), nullable=False)
    total_budget: Mapped[float] = mapped_column(Numeric(20, 8), nullable=False)
    max_position_pct_per_trade: Mapped[float] = mapped_column(Numeric(8, 6), nullable=False)
    max_total_exposure_pct: Mapped[float] = mapped_column(Numeric(8, 6), nullable=False)
    max_daily_loss_pct: Mapped[float] = mapped_column(Numeric(8, 6), nullable=False)
    max_drawdown_pct: Mapped[float] = mapped_column(Numeric(8, 6), nullable=False)
    allow_leverage: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    allow_auto_trade: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    requires_human_confirm: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    emergency_stop: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))


class StrategyRiskPolicyBinding(UUIDMixin, Base):
    __tablename__ = "strategy_risk_policy_bindings"

    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    strategy_version_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_versions.id", ondelete="CASCADE"), nullable=False,
    )
    risk_policy_version_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("risk_policy_versions.id"), nullable=False,
    )
    capital_pool_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("capital_pools.id"), nullable=False,
    )
    mode: Mapped[str] = mapped_column(String(16), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (UniqueConstraint("strategy_version_id", "mode"),)


@event.listens_for(StrategyRiskPolicyBinding, "before_insert")
def _fill_binding_tenant(mapper, connection, target) -> None:
    if target.tenant_id is not None or target.strategy_version_id is None:
        return
    from app.domain.strategy import StrategyVersion

    target.tenant_id = connection.execute(
        select(StrategyVersion.tenant_id).where(
            StrategyVersion.id == target.strategy_version_id
        )
    ).scalar()
