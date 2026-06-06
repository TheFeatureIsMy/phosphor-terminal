"""Stop Protection Snapshots — 止损保护快照"""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Numeric, Boolean, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class StopProtectionSnapshot(UUIDMixin, Base):
    __tablename__ = "stop_protection_snapshots"

    position_id: Mapped[str] = mapped_column(String(64), nullable=False)
    symbol: Mapped[str] = mapped_column(String(32), nullable=False)
    side: Mapped[str] = mapped_column(String(8), nullable=False)
    entry_price: Mapped[float] = mapped_column(Numeric(20, 8), nullable=False)

    raw_structure_stop: Mapped[float | None] = mapped_column(Numeric(20, 8))
    last_known_good_stop: Mapped[float | None] = mapped_column(Numeric(20, 8))
    secure_runtime_stop: Mapped[float | None] = mapped_column(Numeric(20, 8))
    exchange_protective_stop: Mapped[float | None] = mapped_column(Numeric(20, 8))

    volatility_locked: Mapped[bool] = mapped_column(nullable=False, server_default="false")
    stop_update_allowed: Mapped[bool] = mapped_column(nullable=False, server_default="true")

    reason_codes: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="[]")
    structure_data: Mapped[dict | None] = mapped_column(JSONB)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )

    __table_args__ = (
        Index("idx_stop_prot_position", "position_id", "created_at"),
        Index("idx_stop_prot_symbol", "symbol", "created_at"),
    )
