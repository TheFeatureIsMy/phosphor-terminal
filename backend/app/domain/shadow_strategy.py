"""Shadow Strategy Generator — §7 交易后策略进化"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, Integer, Numeric, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class TradeReviewLabel(UUIDMixin, Base):
    __tablename__ = "trade_review_labels"

    trade_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    runtime_snapshot_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    feature_snapshot_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    label: Mapped[str] = mapped_column(String(128), nullable=False)
    label_source: Mapped[str] = mapped_column(String(32), nullable=False)
    confidence: Mapped[float | None] = mapped_column(Numeric())
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_trade_review_labels_trade", "trade_id"),
    )


class FailureClusterRecord(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "failure_clusters"

    strategy_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    label: Mapped[str] = mapped_column(String(128), nullable=False)
    sample_size: Mapped[int] = mapped_column(Integer, nullable=False)
    total_loss: Mapped[float | None] = mapped_column(Numeric())
    avg_loss: Mapped[float | None] = mapped_column(Numeric())
    common_features: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="{}")
    representative_trade_ids: Mapped[list] = mapped_column(JSONB, nullable=False, server_default="[]")
    status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="active")

    __table_args__ = (
        Index("idx_failure_clusters_strategy", "strategy_id"),
    )


class ShadowStrategyDraft(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "shadow_strategy_drafts"

    source_type: Mapped[str] = mapped_column(String(32), nullable=False)
    source_failure_cluster_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    target_strategy_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    target_strategy_version_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    title: Mapped[str] = mapped_column(String(256), nullable=False)
    summary: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(32), nullable=False, server_default="generated")
    failure_pattern: Mapped[dict | None] = mapped_column(JSONB)
    dsl_patch: Mapped[list] = mapped_column(JSONB, nullable=False)
    validation_state: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="{}")
    backtest_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    dryrun_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    created_by: Mapped[str] = mapped_column(String(64), nullable=False, server_default="growth_engine")

    __table_args__ = (
        Index("idx_shadow_drafts_strategy", "target_strategy_id"),
        Index("idx_shadow_drafts_status", "status"),
    )


class StrategyVersionUpgradeRequest(UUIDMixin, Base):
    __tablename__ = "strategy_version_upgrade_requests"

    strategy_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    from_version_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    shadow_strategy_draft_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    proposed_version_name: Mapped[str | None] = mapped_column(String(128))
    diff_summary: Mapped[str | None] = mapped_column(Text)
    validation_report: Mapped[dict | None] = mapped_column(JSONB)
    approval_status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="pending")
    approved_by: Mapped[str | None] = mapped_column(String(128))
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("idx_upgrade_requests_strategy", "strategy_id"),
    )
