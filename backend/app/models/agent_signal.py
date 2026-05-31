from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, JSON, String, Text

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AgentProfile(Base):
    __tablename__ = "agent_profiles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False, unique=True)
    kind = Column(String, nullable=False, default="research")
    status = Column(String, nullable=False, default="active")
    description = Column(Text, nullable=True)
    last_heartbeat_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class AgentSignal(Base):
    __tablename__ = "agent_signals"

    id = Column(Integer, primary_key=True, autoincrement=True)
    agent_id = Column(Integer, ForeignKey("agent_profiles.id"), nullable=False, index=True)
    source = Column(String, nullable=False, default="manual")
    message_type = Column(String, nullable=False, default="research")
    symbol = Column(String, nullable=False, index=True)
    market = Column(String, nullable=False, default="stock")
    direction = Column(String, nullable=True)
    rating = Column(String, nullable=True)
    confidence = Column(Float, nullable=True)
    target_price = Column(Float, nullable=True)
    stop_loss = Column(Float, nullable=True)
    time_horizon = Column(String, nullable=True)
    content = Column(Text, nullable=False)
    evidence = Column(JSON, default=dict)
    linked_research_run_id = Column(Integer, nullable=True, index=True)
    linked_strategy_id = Column(Integer, nullable=True, index=True)
    created_at = Column(DateTime, default=_utcnow)


class AgentSignalScore(Base):
    __tablename__ = "agent_signal_scores"

    id = Column(Integer, primary_key=True, autoincrement=True)
    signal_id = Column(Integer, ForeignKey("agent_signals.id"), nullable=False, index=True)
    verifiability_score = Column(Float, nullable=False)
    evidence_score = Column(Float, nullable=False)
    specificity_score = Column(Float, nullable=False)
    novelty_score = Column(Float, nullable=False)
    risk_score = Column(Float, nullable=False)
    overall_score = Column(Float, nullable=False)
    scored_by = Column(String, nullable=False, default="heuristic-v1")
    created_at = Column(DateTime, default=_utcnow)
