"""DryRunRun model — tracks Freqtrade dry-run process lifecycle."""
from datetime import datetime, timezone

from sqlalchemy import Column, Integer, String, Float, JSON, DateTime

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class DryRunRun(Base):
    __tablename__ = "dryrun_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    strategy_id = Column(Integer, nullable=False, index=True)
    strategy_version_id = Column(String, nullable=True, index=True)
    command_id = Column(String, nullable=True, index=True)
    dsl_hash = Column(String, nullable=True)
    status = Column(String, nullable=False, default="starting")
    pid = Column(Integer, nullable=True)
    api_port = Column(Integer, nullable=True)
    api_url = Column(String, nullable=True)
    config_path = Column(String, nullable=True)
    rules_path = Column(String, nullable=True)
    symbols = Column(JSON, default=list)
    stake_amount = Column(Float, default=100)
    max_open_trades = Column(Integer, default=5)
    initial_wallet = Column(Float, default=10000)
    exchange = Column(String, default="binance")
    total_trades = Column(Integer, default=0)
    open_trades = Column(Integer, default=0)
    total_profit = Column(Float, default=0)
    last_synced_at = Column(DateTime, nullable=True)
    error_message = Column(String, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    started_at = Column(DateTime, nullable=True)
    stopped_at = Column(DateTime, nullable=True)
