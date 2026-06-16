"""System settings persistence model."""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Column, DateTime, Index, Integer, JSON, String,
)

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class SystemSetting(Base):
    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True, autoincrement=True)
    key = Column(String(128), nullable=False, unique=True)
    value = Column(JSON, nullable=False)
    category = Column(String(32), nullable=False)
    updated_at = Column(DateTime, nullable=False, default=_utcnow, onupdate=_utcnow)
    updated_by = Column(String(64), nullable=True)

    __table_args__ = (
        Index("ix_system_settings_category", "category"),
    )
