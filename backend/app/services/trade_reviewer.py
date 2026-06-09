from __future__ import annotations

import json
import logging
import uuid
from dataclasses import dataclass, field
from typing import Optional

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

REVIEW_PROMPT = """You are a trading analyst reviewing a completed trade.

Trade details:
- Symbol: {symbol}
- Direction: {direction}
- Entry price: {entry_price}
- Exit price: {exit_price}
- Profit: {profit_pct:.2f}%
- Duration: {duration}

Decision context at entry:
- Structure score: {structure_score}
- Market regime: {regime}
- AI risk score: {ai_risk}
- Reason codes: {reason_codes}
- Sweep state: {sweep_state}
- FVG state: {fvg_state}

Analyze this trade and respond with a JSON object:
{{
    "assessment": "one paragraph analysis of what went right or wrong",
    "labels": ["list", "of", "applicable", "labels"],
    "suggestion": "one specific improvement suggestion or null"
}}

Valid labels: good_structure_entry, entered_before_reclaim_confirmation, stop_too_close_to_liquidity_pool, failed_due_to_news_shock, failed_due_to_market_regime_shift, structure_add_rejected_risk_budget, ai_cache_expired_reduced_size, snapshot_disconnect_emergency_close

Respond ONLY with JSON."""


@dataclass
class TradeReview:
    trade_id: str
    snapshot_uid: Optional[str]
    outcome: str
    ai_assessment: str
    identified_labels: list[str] = field(default_factory=list)
    improvement_suggestion: Optional[str] = None
    confidence: float = 0.5


class TradeReviewer:
    def __init__(self, llm_service=None):
        self._llm = llm_service

    async def review_trade(
        self,
        trade_id: str,
        symbol: str,
        direction: str,
        entry_price: float,
        exit_price: float,
        profit_pct: float,
        duration: str = "unknown",
        snapshot: dict | None = None,
    ) -> TradeReview:
        outcome = "win" if profit_pct > 0 else ("breakeven" if profit_pct == 0 else "loss")
        snapshot_uid = snapshot.get("snapshot_id") if snapshot else None

        struct_ctx = (snapshot or {}).get("structure_context", {})
        ai_ctx = (snapshot or {}).get("ai_context", {})

        if not self._llm:
            return TradeReview(
                trade_id=trade_id,
                snapshot_uid=snapshot_uid,
                outcome=outcome,
                ai_assessment="LLM not available for review",
                confidence=0.0,
            )

        try:
            prompt = REVIEW_PROMPT.format(
                symbol=symbol, direction=direction,
                entry_price=entry_price, exit_price=exit_price,
                profit_pct=profit_pct, duration=duration,
                structure_score=struct_ctx.get("structure_score", "N/A"),
                regime=struct_ctx.get("market_regime", "unknown"),
                ai_risk=ai_ctx.get("ai_risk_score", "N/A"),
                reason_codes=str((snapshot or {}).get("reason_codes", [])),
                sweep_state=str(struct_ctx.get("sweep", "N/A")),
                fvg_state=str(struct_ctx.get("fvg", "N/A")),
            )
            response = await self._llm.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=500,
            )
            data = json.loads(response.content)
            return TradeReview(
                trade_id=trade_id,
                snapshot_uid=snapshot_uid,
                outcome=outcome,
                ai_assessment=data.get("assessment", ""),
                identified_labels=data.get("labels", []),
                improvement_suggestion=data.get("suggestion"),
                confidence=0.6,
            )
        except Exception:
            logger.warning("AI review failed for trade %s", trade_id)
            return TradeReview(
                trade_id=trade_id,
                snapshot_uid=snapshot_uid,
                outcome=outcome,
                ai_assessment="review_unavailable",
                confidence=0.0,
            )

    # ------------------------------------------------------------------
    # Label persistence — TradeReviewLabel (shadow_strategy domain)
    # ------------------------------------------------------------------

    @staticmethod
    def add_label(
        db: Session,
        trade_id: str | uuid.UUID,
        label: str,
        label_source: str = "human",
        confidence: float | None = None,
        notes: str | None = None,
        runtime_snapshot_id: uuid.UUID | str | None = None,
        feature_snapshot_id: uuid.UUID | str | None = None,
    ):
        """Persist a single TradeReviewLabel row and return it."""
        from app.domain.shadow_strategy import TradeReviewLabel

        _trade_id = uuid.UUID(str(trade_id)) if not isinstance(trade_id, uuid.UUID) else trade_id
        _snap_id = uuid.UUID(str(runtime_snapshot_id)) if runtime_snapshot_id else None
        _feat_id = uuid.UUID(str(feature_snapshot_id)) if feature_snapshot_id else None

        row = TradeReviewLabel(
            trade_id=_trade_id,
            runtime_snapshot_id=_snap_id,
            feature_snapshot_id=_feat_id,
            label=label,
            label_source=label_source,
            confidence=confidence,
            notes=notes,
        )
        db.add(row)
        db.flush()
        logger.info("TradeReviewLabel added: trade=%s label=%s source=%s", trade_id, label, label_source)
        return row

    @staticmethod
    def get_labels(
        db: Session,
        trade_id: str | uuid.UUID,
    ) -> list:
        """Return all TradeReviewLabel rows for a given trade."""
        from app.domain.shadow_strategy import TradeReviewLabel

        _trade_id = uuid.UUID(str(trade_id)) if not isinstance(trade_id, uuid.UUID) else trade_id
        return (
            db.query(TradeReviewLabel)
            .filter(TradeReviewLabel.trade_id == _trade_id)
            .order_by(TradeReviewLabel.created_at.desc())
            .all()
        )
