"""Live Readiness Checks — 实盘准入检查记录"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Integer, Boolean, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class LiveReadinessCheck(UUIDMixin, Base):
    __tablename__ = "live_readiness_checks"

    account_id: Mapped[str] = mapped_column(String(64), nullable=False, server_default="default")
    score: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    state: Mapped[str] = mapped_column(
        String(32), nullable=False, server_default="NOT_READY",
    )  # LIVE_READY / LIVE_SMALL_READY / PAPER_ONLY / RISK_LOCKED / EMERGENCY_LOCKED / NOT_READY

    can_start_paper: Mapped[bool] = mapped_column(nullable=False, server_default="false")
    can_start_live_small: Mapped[bool] = mapped_column(nullable=False, server_default="false")
    can_start_full_live: Mapped[bool] = mapped_column(nullable=False, server_default="false")

    checks: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="[]")
    blocking_reasons: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="[]")
    warnings: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="[]")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )

    __table_args__ = (
        Index("idx_readiness_account_created", "account_id", "created_at"),
    )
