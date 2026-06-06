"""Strategy Center — v2.5 ERD §5"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, Integer, DateTime, ForeignKey, UniqueConstraint, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import func, JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class StrategyV2(UUIDMixin, TimestampMixin, Base):
    """v2.5 Strategy identity. Suffix _v2 avoids clash with legacy model; removed in Phase 01 cleanup."""
    __tablename__ = "strategies_v2"

    name: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    strategy_type: Mapped[str] = mapped_column(String(64), nullable=False)
    source_type: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="draft")


class StrategyVersion(UUIDMixin, Base):
    __tablename__ = "strategy_versions"

    strategy_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategies_v2.id"), nullable=False,
    )
    version_no: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, server_default="draft")
    dsl_version: Mapped[str] = mapped_column(String(8), nullable=False)
    rule_dsl: Mapped[dict] = mapped_column(JSONB, nullable=False)
    dsl_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    created_by: Mapped[str] = mapped_column(String(128), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("strategy_id", "version_no"),
        Index("idx_strategy_versions_strategy", "strategy_id", version_no.desc()),
    )


class StrategyRuleDSLVersion(UUIDMixin, Base):
    __tablename__ = "strategy_rule_dsl_versions"

    strategy_version_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategy_versions.id"), nullable=False,
    )
    dsl_version: Mapped[str] = mapped_column(String(8), nullable=False)
    rule_dsl: Mapped[dict] = mapped_column(JSONB, nullable=False)
    dsl_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    migration_from: Mapped[str | None] = mapped_column(String(8))
    validation_result: Mapped[dict | None] = mapped_column(JSONB)
    validator_version: Mapped[str] = mapped_column(String(8), nullable=False, server_default="2.5")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
