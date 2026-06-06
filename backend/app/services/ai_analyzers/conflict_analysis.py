from __future__ import annotations

import logging

from .base import BaseAnalyzer, AnalyzerResult

logger = logging.getLogger(__name__)


class ConflictAnalyzer(BaseAnalyzer):
    async def analyze(self, symbol: str, context: dict) -> AnalyzerResult:
        flags = []
        risk_score = 0.0

        structure_direction = context.get("structure_direction")
        news_bias = context.get("news_bias")
        whale_risk = context.get("whale_risk_score", 0.0)

        if structure_direction and news_bias:
            if structure_direction == "bullish" and news_bias == "bearish":
                flags.append("structure_news_conflict")
                risk_score += 0.3
            elif structure_direction == "bearish" and news_bias == "bullish":
                flags.append("structure_news_conflict")
                risk_score += 0.3

        if whale_risk > 0.6:
            flags.append("high_whale_risk")
            risk_score += 0.2

        analyzer_count = context.get("analyzer_count", 0)
        disagreement_pct = context.get("disagreement_pct", 0)
        if analyzer_count >= 2 and disagreement_pct > 0.5:
            flags.append("multi_factor_disagreement")
            risk_score += 0.15

        return AnalyzerResult(
            analyzer_name="conflict_analysis",
            risk_score=min(1.0, risk_score),
            risk_flags=flags,
            summary=f"Detected {len(flags)} conflicts" if flags else "No conflicts detected",
            confidence=0.7 if flags else 0.8,
        )
