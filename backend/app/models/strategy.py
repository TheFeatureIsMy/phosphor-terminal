from datetime import datetime, timezone

from sqlalchemy import Column, Integer, String, Float, JSON, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship
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
    tags = Column(JSON, default=[])
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


class BacktestRun(Base):
    __tablename__ = "backtest_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    strategy_id = Column(Integer, nullable=False, index=True)
    strategy_version_id = Column(String, nullable=True, index=True)
    command_id = Column(String, nullable=True, index=True)
    dsl_hash = Column(String, nullable=True)
    status = Column(String, nullable=False, default="pending")
    start_date = Column(String, nullable=False)
    end_date = Column(String, nullable=False)
    initial_capital = Column(Float, nullable=False)
    symbols = Column(JSON, default=list)
    config = Column(JSON, default=dict)
    result = Column(JSON, default=dict)
    sharpe_ratio = Column(Float, default=0)
    max_drawdown = Column(Float, default=0)
    win_rate = Column(Float, default=0)
    total_return = Column(Float, default=0)
    profit_factor = Column(Float, default=0)
    total_trades = Column(Integer, default=0)
    data_source = Column(JSON, default=dict)
    error_message = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    completed_at = Column(DateTime, nullable=True)


class NotificationRecord(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, autoincrement=True)
    type = Column(String, nullable=False, default="system")
    title = Column(String, nullable=False)
    message = Column(String, nullable=False)
    is_read = Column(Integer, default=0)
    created_at = Column(DateTime, default=_utcnow)


class CanvasWorkflow(Base):
    __tablename__ = "canvas_workflows"

    id = Column(String, primary_key=True, default=lambda: str(__import__('uuid').uuid4()))
    strategy_id = Column(Integer, ForeignKey("strategies.id"), nullable=False, index=True)
    graph_json = Column(Text, nullable=False)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    strategy = relationship("Strategy", backref="canvas_workflows")
