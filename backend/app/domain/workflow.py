"""Daily Trading Loop — Workflow Layer §4"""
import uuid
from datetime import date, datetime

from sqlalchemy import func, String, Text, Date, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin, TimestampMixin


class WorkflowState(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "workflow_states"

    workflow_date: Mapped[date] = mapped_column(Date, nullable=False, unique=True)
    global_state: Mapped[str] = mapped_column(String(24), nullable=False, server_default="not_started")
    current_step: Mapped[str] = mapped_column(String(32), nullable=False, server_default="mission_control")
    steps: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="{}")
    summary: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (
        Index("idx_workflow_states_date", "workflow_date", unique=True),
    )
