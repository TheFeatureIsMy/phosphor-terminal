"""Strategy/Freqtrade Run instances — v2.5 ERD §7"""
import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime, ForeignKey, Integer, String, Text, event, func, select,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class StrategyRun(UUIDMixin, Base):
    __tablename__ = "strategy_runs"

    strategy_version_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_versions.id", ondelete="CASCADE"), nullable=False,
    )
    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    capital_pool_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("capital_pools.id"),
    )
    mode: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, server_default="created")
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    stopped_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class FreqtradeRun(UUIDMixin, Base):
    __tablename__ = "freqtrade_runs"

    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    strategy_run_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_runs.id", ondelete="CASCADE"), nullable=False,
    )
    container_id: Mapped[str | None] = mapped_column(String(128))
    config_path: Mapped[str] = mapped_column(String(512), nullable=False)
    rules_path: Mapped[str] = mapped_column(String(512), nullable=False)
    rule_package_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    fixed_strategy_template: Mapped[str] = mapped_column(
        String(128), nullable=False, server_default="PulseDeskUniversalStrategy.py",
    )
    ft_db_url: Mapped[str | None] = mapped_column(String(512))
    status: Mapped[str] = mapped_column(String(32), nullable=False)
    last_heartbeat_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_reconciled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    api_base_url: Mapped[str | None] = mapped_column(String(256))
    websocket_url: Mapped[str | None] = mapped_column(String(256))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


@event.listens_for(FreqtradeRun, "before_insert")
def _fill_freqtrade_run_tenant(mapper, connection, target) -> None:
    if target.tenant_id is not None or target.strategy_run_id is None:
        return
    target.tenant_id = connection.execute(
        select(StrategyRun.tenant_id).where(StrategyRun.id == target.strategy_run_id)
    ).scalar()
