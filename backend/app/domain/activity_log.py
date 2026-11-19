"""Strategy activity log — records lifecycle events for the workbench activity panel."""
import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime, ForeignKey, Index, Integer, String, Text, event, func, select,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class StrategyActivityLog(UUIDMixin, Base):
    __tablename__ = "strategy_activity_log"

    tenant_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    strategy_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategies_v2.id", ondelete="CASCADE"), nullable=False,
    )
    kind: Mapped[str] = mapped_column(String(64), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    actor: Mapped[str | None] = mapped_column(String(128))
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    delta: Mapped[dict | None] = mapped_column(JSONB)
    ref_kind: Mapped[str | None] = mapped_column(String(32))
    ref_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))

    __table_args__ = (
        Index("idx_activity_strategy_time", "strategy_id", occurred_at.desc()),
    )


@event.listens_for(StrategyActivityLog, "before_insert")
def _fill_activity_tenant(mapper, connection, target) -> None:
    if target.tenant_id is not None or target.strategy_id is None:
        return
    from app.domain.strategy import StrategyV2

    target.tenant_id = connection.execute(
        select(StrategyV2.tenant_id).where(StrategyV2.id == target.strategy_id)
    ).scalar()
