from __future__ import annotations

from sqlalchemy import (
    BigInteger, Column, Index, Integer, Numeric, String, Text,
    TIMESTAMP, func,
)
from sqlalchemy.dialects.postgresql import JSONB

from app.database.base import Base


class DecisionSnapshot(Base):
    __tablename__ = "decision_snapshots"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    snapshot_uid = Column(String(128), unique=True, nullable=False)
    strategy_id = Column(String(128), nullable=False)
    strategy_version = Column(String(32))
    exchange = Column(String(32), nullable=False)
    symbol = Column(String(32), nullable=False)
    timeframe = Column(String(16), nullable=False)

    candidate_signal = Column(JSONB, nullable=False, server_default='{}')
    indicator_context = Column(JSONB, nullable=False, server_default='{}')
    structure_context = Column(JSONB, nullable=False, server_default='{}')
    ai_context = Column(JSONB, nullable=False, server_default='{}')
    liquidity_execution_context = Column(JSONB, nullable=False, server_default='{}')
    risk_context = Column(JSONB, nullable=False, server_default='{}')
    execution_plan = Column(JSONB, nullable=False, server_default='{}')

    final_decision = Column(String(32), nullable=False)
    reject_reason = Column(Text)
    confidence = Column(Numeric(6, 4))
    reason_codes = Column(JSONB, nullable=False, server_default='[]')

    latency_ms = Column(Integer)
    fast_track_latency_ms = Column(Integer)
    ai_cache_age_ms = Column(Integer)

    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (
        Index("idx_ds_strategy_time", "strategy_id", created_at.desc()),
        Index("idx_ds_symbol_time", "symbol", "timeframe", created_at.desc()),
        Index("idx_ds_final_decision", "final_decision", created_at.desc()),
    )


class RiskDecisionLog(Base):
    __tablename__ = "risk_decision_logs"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    snapshot_uid = Column(String(128))
    account_id = Column(String(128), nullable=False)
    risk_state = Column(String(32), nullable=False)
    decision = Column(String(32), nullable=False)
    reason_code = Column(String(128))

    account_equity = Column(Numeric(30, 12))
    risk_budget = Column(Numeric(30, 12))
    used_risk = Column(Numeric(30, 12))
    remaining_risk = Column(Numeric(30, 12))
    daily_pnl = Column(Numeric(30, 12))
    weekly_pnl = Column(Numeric(30, 12))
    open_exposure = Column(Numeric(30, 12))
    liquidation_distance_pct = Column(Numeric(10, 6))

    metadata_ = Column("metadata", JSONB, nullable=False, server_default='{}')
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())


class TradeLearningLabel(Base):
    __tablename__ = "trade_learning_labels"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    trade_id = Column(String(128), nullable=False)
    snapshot_uid = Column(String(128))
    label_type = Column(String(64), nullable=False)
    label_value = Column(String(128), nullable=False)
    confidence = Column(Numeric(6, 4))
    source = Column(String(64), nullable=False)
    notes = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())


class LiquidityPool(Base):
    __tablename__ = "liquidity_pools"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    exchange = Column(String(32), nullable=False)
    symbol = Column(String(32), nullable=False)
    timeframe = Column(String(16), nullable=False)
    pool_type = Column(String(64), nullable=False)
    side = Column(String(16), nullable=False)
    price_level = Column(Numeric(30, 12), nullable=False)
    initial_strength = Column(Numeric(6, 4), nullable=False)
    current_strength = Column(Numeric(6, 4))
    status = Column(String(32), nullable=False, server_default="active")
    touched_count = Column(Integer, nullable=False, server_default="0")
    candle_time = Column(TIMESTAMP(timezone=True), nullable=False)
    swept_at = Column(TIMESTAMP(timezone=True))
    invalidated_at = Column(TIMESTAMP(timezone=True))
    metadata_ = Column("metadata", JSONB, nullable=False, server_default='{}')
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())


class StructureZone(Base):
    __tablename__ = "structure_zones"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    exchange = Column(String(32), nullable=False)
    symbol = Column(String(32), nullable=False)
    timeframe = Column(String(16), nullable=False)
    zone_type = Column(String(64), nullable=False)
    direction = Column(String(16), nullable=False)
    price_top = Column(Numeric(30, 12), nullable=False)
    price_bottom = Column(Numeric(30, 12), nullable=False)
    initial_strength = Column(Numeric(6, 4), nullable=False)
    current_strength = Column(Numeric(6, 4))
    filled_ratio = Column(Numeric(6, 4), server_default="0")
    status = Column(String(32), nullable=False, server_default="active")
    touched_count = Column(Integer, nullable=False, server_default="0")
    candle_time = Column(TIMESTAMP(timezone=True), nullable=False)
    invalidated_at = Column(TIMESTAMP(timezone=True))
    metadata_ = Column("metadata", JSONB, nullable=False, server_default='{}')
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
