from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, Integer, JSON, String, Text

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class KnowledgeDocument(Base):
    __tablename__ = "knowledge_documents"

    id = Column(Integer, primary_key=True, autoincrement=True)
    filename = Column(String, nullable=False)
    content_hash = Column(String, nullable=False, unique=True)
    content_type = Column(String, nullable=False, default="text/plain")
    chunk_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=_utcnow)


class KnowledgeChunk(Base):
    __tablename__ = "knowledge_chunks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    document_id = Column(Integer, nullable=False, index=True)
    chunk_index = Column(Integer, nullable=False)
    content = Column(Text, nullable=False)
    keywords = Column(JSON, default=list)
    created_at = Column(DateTime, default=_utcnow)


class GeneratedStrategyArtifact(Base):
    __tablename__ = "generated_strategy_artifacts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    prompt = Column(Text, nullable=False)
    risk_level = Column(String, default="medium")
    market = Column(String, default="crypto")
    strategy_name = Column(String, nullable=False)
    strategy_type = Column(String, default="rag_generated")
    code = Column(Text, nullable=False)
    safety_status = Column(String, default="pending")
    safety_findings = Column(JSON, default=list)
    backtest_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=_utcnow)


class ForecastRun(Base):
    __tablename__ = "forecast_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    symbol = Column(String, nullable=False, index=True)
    model = Column(String, nullable=False)
    horizon = Column(String, nullable=False)
    status = Column(String, default="completed")
    points = Column(JSON, default=list)
    confidence = Column(Float, nullable=True)
    created_at = Column(DateTime, default=_utcnow)


class FactorResearchRun(Base):
    __tablename__ = "factor_research_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    market = Column(String, default="crypto")
    universe = Column(JSON, default=list)
    factor_name = Column(String, nullable=False)
    status = Column(String, default="completed")
    metrics = Column(JSON, default=dict)
    qlib_config = Column(JSON, default=dict)
    created_at = Column(DateTime, default=_utcnow)


class FreqAIRun(Base):
    __tablename__ = "freqai_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    strategy_id = Column(Integer, nullable=True, index=True)
    model_name = Column(String, nullable=False)
    status = Column(String, default="queued")
    training_config = Column(JSON, default=dict)
    metrics = Column(JSON, default=dict)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
