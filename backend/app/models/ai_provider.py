from datetime import datetime, timezone

from sqlalchemy import (
    Column, DateTime, Float, ForeignKey, Integer, String,
)

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AIUsageLog(Base):
    __tablename__ = "ai_usage_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    provider = Column(String, nullable=False)
    model = Column(String, nullable=False)
    service = Column(String, nullable=False)
    tokens_used = Column(Integer, nullable=False)
    latency_ms = Column(Float, nullable=False)
    provider_config_id = Column(
        Integer,
        ForeignKey("provider_configs.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )
    created_at = Column(DateTime, default=_utcnow, nullable=False)
