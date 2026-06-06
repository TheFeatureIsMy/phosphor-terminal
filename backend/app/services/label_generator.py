from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from sqlalchemy.orm import Session
    from app.domain.runtime import TradeLearningLabel

logger = logging.getLogger(__name__)


@dataclass
class TradeLabel:
    label_type: str
    label_value: str
    confidence: float
    source: str


def generate_labels(
    trade_id: str,
    profit_pct: float,
    snapshot: dict | None,
) -> list[TradeLabel]:
    labels = []
    is_win = profit_pct > 0
    is_loss = profit_pct < 0

    struct = (snapshot or {}).get("structure_context", {})
    ai = (snapshot or {}).get("ai_context", {})
    exec_plan = (snapshot or {}).get("execution_plan", {})
    reasons = (snapshot or {}).get("reason_codes", [])

    # Good structure entry
    sweep = struct.get("sweep")
    if is_win and sweep and sweep.get("state") == "confirmed_sweep":
        labels.append(TradeLabel("learning", "good_structure_entry", 1.0, "deterministic"))

    # Entered before reclaim
    if is_loss and sweep and sweep.get("state") != "confirmed_sweep":
        labels.append(TradeLabel("learning", "entered_before_reclaim_confirmation", 0.9, "deterministic"))

    # Stop too close to liquidity pool
    if is_loss and struct.get("structure_score", 100) < 50:
        labels.append(TradeLabel("learning", "stop_too_close_to_liquidity_pool", 0.7, "deterministic"))

    # AI cache issues
    cache_state = ai.get("cache_state", "missing")
    if cache_state in ("soft_expired", "hard_expired"):
        labels.append(TradeLabel("learning", "ai_cache_expired_reduced_size", 1.0, "deterministic"))

    if cache_state == "missing":
        labels.append(TradeLabel("learning", "ai_cache_missing", 1.0, "deterministic"))

    # Disconnect
    if any("disconnect" in str(r) for r in reasons):
        labels.append(TradeLabel("learning", "snapshot_disconnect_emergency_close", 1.0, "deterministic"))

    # Market regime issues
    regime = struct.get("market_regime", "unknown")
    if is_loss and regime in ("panic", "news_shock", "high_volatility"):
        labels.append(TradeLabel("learning", f"failed_due_to_{regime}", 0.8, "deterministic"))

    # Win in range market
    if is_win and regime == "range":
        labels.append(TradeLabel("learning", "successful_range_trade", 0.8, "deterministic"))

    return labels


class LabelPersistence:
    def __init__(self, db: "Session"):
        self._db = db

    def persist_labels(self, trade_id: str, snapshot_uid: str | None,
                       labels: list[TradeLabel]) -> list:
        from app.domain.runtime import TradeLearningLabel

        rows = []
        for label in labels:
            try:
                row = TradeLearningLabel(
                    trade_id=trade_id,
                    snapshot_uid=snapshot_uid,
                    label_type=label.label_type,
                    label_value=label.label_value,
                    confidence=label.confidence,
                    source=label.source,
                )
                self._db.add(row)
                rows.append(row)
            except Exception:
                logger.exception("failed to persist label %s for trade %s",
                                label.label_value, trade_id)
        self._db.flush()
        return rows
