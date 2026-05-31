from datetime import datetime, timezone

from sqlalchemy import Column, Date, DateTime, Float, ForeignKey, Integer, JSON, String, Text

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AIResearchRun(Base):
    __tablename__ = "ai_research_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    symbol = Column(String, nullable=False, index=True)
    asset_type = Column(String, nullable=False, default="stock")
    analysis_date = Column(Date, nullable=False)
    provider = Column(String, nullable=False, default="tradingagents")
    runtime_config = Column(JSON, default=dict)
    status = Column(String, nullable=False, default="pending")
    rating = Column(String, nullable=True)
    confidence = Column(Float, nullable=True)
    final_decision = Column(Text, nullable=True)
    market_report = Column(Text, nullable=True)
    sentiment_report = Column(Text, nullable=True)
    news_report = Column(Text, nullable=True)
    fundamentals_report = Column(Text, nullable=True)
    investment_debate = Column(JSON, default=dict)
    risk_debate = Column(JSON, default=dict)
    error_message = Column(Text, nullable=True)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)


class AIResearchLink(Base):
    __tablename__ = "ai_research_links"

    id = Column(Integer, primary_key=True, autoincrement=True)
    research_run_id = Column(Integer, ForeignKey("ai_research_runs.id"), nullable=False, index=True)
    strategy_id = Column(Integer, nullable=True, index=True)
    backtest_id = Column(Integer, nullable=True, index=True)
    link_type = Column(String, nullable=False)
    created_at = Column(DateTime, default=_utcnow)
