from datetime import datetime, timezone

from sqlalchemy import Column, Integer, String, Float, JSON, DateTime
from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


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
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class RiskEvent(Base):
    __tablename__ = "risk_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    event_type = Column(String, nullable=False)
    strategy_id = Column(Integer, nullable=True)
    market = Column(String, default="crypto")
    severity = Column(String, nullable=False)
    description = Column(String, nullable=True)
    action_taken = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)


class CorrelationSnapshot(Base):
    __tablename__ = "correlation_snapshots"

    id = Column(Integer, primary_key=True, autoincrement=True)
    symbol_a = Column(String, nullable=False)
    symbol_b = Column(String, nullable=False)
    market = Column(String, default="crypto")
    correlation = Column(Float, nullable=False)
    window_days = Column(Integer, default=30)
    alert_level = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)


class AttributionReport(Base):
    __tablename__ = "attribution_reports"

    id = Column(Integer, primary_key=True, autoincrement=True)
    trade_id = Column(Integer, nullable=False)
    strategy_id = Column(Integer, nullable=True)
    feature_contributions = Column(JSON, default=dict)
    top_loss_factors = Column(JSON, default=list)
    market_context = Column(JSON, default=dict)
    summary = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)


class SlippageAttribution(Base):
    __tablename__ = "slippage_attribution"

    id = Column(Integer, primary_key=True, autoincrement=True)
    trade_id = Column(Integer, nullable=False)
    signal_price = Column(Float, nullable=False)
    filled_price = Column(Float, nullable=False)
    execution_slippage = Column(Float, nullable=False)
    spread_cost = Column(Float, default=0)
    market_impact = Column(Float, default=0)
    latency_cost = Column(Float, default=0)
    slippage_pct = Column(Float, nullable=False)
    diagnosis = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)


class SentimentData(Base):
    __tablename__ = "sentiment_data"

    id = Column(Integer, primary_key=True, autoincrement=True)
    symbol = Column(String, nullable=False)
    market = Column(String, default="crypto")
    source = Column(String, nullable=False)
    score = Column(Float, nullable=False)
    raw_text = Column(String, nullable=True)
    model = Column(String, default="finbert")
    timestamp = Column(DateTime, default=_utcnow)


class PortfolioStressTest(Base):
    __tablename__ = "portfolio_stress_tests"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, default=1)
    market = Column(String, default="crypto")
    scenario = Column(String, nullable=False)
    portfolio_var_95 = Column(Float, nullable=False)
    portfolio_cvar = Column(Float, nullable=False)
    max_potential_drawdown = Column(Float, nullable=False)
    concentration_risk = Column(JSON, default=dict)
    recommendations = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
