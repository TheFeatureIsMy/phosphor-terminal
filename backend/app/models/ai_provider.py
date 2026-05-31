from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Float, Integer, String

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AIProviderConfig(Base):
    __tablename__ = "ai_provider_configs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    provider = Column(String, nullable=False)  # openai, anthropic, ollama
    api_key_encrypted = Column(String, nullable=True)
    base_url = Column(String, nullable=True)
    model = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    priority = Column(Integer, default=0)  # lower = higher priority
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class AIUsageLog(Base):
    __tablename__ = "ai_usage_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    provider = Column(String, nullable=False)
    model = Column(String, nullable=False)
    service = Column(String, nullable=False)  # rag, sentiment, forecast, etc.
    tokens_used = Column(Integer, nullable=False)
    latency_ms = Column(Float, nullable=False)
    created_at = Column(DateTime, default=_utcnow)
