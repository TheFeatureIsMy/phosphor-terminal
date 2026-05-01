from datetime import datetime

from sqlalchemy import Column, Integer, String, Float, JSON, DateTime
from app.database import Base


class Strategy(Base):
    __tablename__ = "strategies"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False)
    type = Column(String, nullable=False, default="ma_cross")
    parameters = Column(JSON, default=dict)
    source = Column(String, default="manual")
    market = Column(String, default="crypto")
    exchange = Column(String, default="binance")
    version = Column(Integer, default=1)
    status = Column(String, default="draft")
    sharpe_ratio = Column(Float, nullable=True)
    max_drawdown = Column(Float, nullable=True)
    freqtrade_strategy_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class RiskEvent(Base):
    __tablename__ = "risk_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    event_type = Column(String, nullable=False)
    strategy_id = Column(Integer, nullable=True)
    market = Column(String, default="crypto")
    severity = Column(String, nullable=False)
    description = Column(String, nullable=True)
    action_taken = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class CorrelationSnapshot(Base):
    __tablename__ = "correlation_snapshots"

    id = Column(Integer, primary_key=True, autoincrement=True)
    symbol_a = Column(String, nullable=False)
    symbol_b = Column(String, nullable=False)
    market = Column(String, default="crypto")
    correlation = Column(Float, nullable=False)
    window_days = Column(Integer, default=30)
    alert_level = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
