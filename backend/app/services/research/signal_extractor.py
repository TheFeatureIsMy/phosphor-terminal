"""Extract SignalCandidates from a ResearchReport.

No LLM call — pure structural extraction from report data.
"""
from __future__ import annotations

import uuid
from typing import Literal

from app.schemas.research_v2 import ResearchReportData, SignalCandidateData


ACTIONABLE_RATINGS = {"Buy", "Overweight", "Sell", "Underweight"}

RATING_TO_DIRECTION: dict[str, str] = {
    "Buy": "long",
    "Overweight": "long",
    "Sell": "short",
    "Underweight": "short",
}


def extract_candidates(report: ResearchReportData) -> list[SignalCandidateData]:
    """Extract zero or more SignalCandidates from a ResearchReport.

    - Hold / risk rating → no candidates (not actionable).
    - Confidence < 0.3 → no candidates (too uncertain).
    """
    if report.rating not in ACTIONABLE_RATINGS:
        return []

    if report.confidence < 0.3:
        return []

    direction_str = RATING_TO_DIRECTION.get(report.rating, report.direction.value if hasattr(report.direction, 'value') else str(report.direction))

    indicators: list[str] = []
    for opinion in report.agent_opinions.values():
        for factor in opinion.key_factors:
            normalized = factor.lower().strip()
            if normalized not in indicators:
                indicators.append(normalized)

    entry_parts: list[str] = []
    exit_parts: list[str] = []
    for role, opinion in report.agent_opinions.items():
        if opinion.stance in ("bullish", "bearish"):
            entry_parts.append(f"[{opinion.role}] {opinion.reasoning[:200]}")

    candidate = SignalCandidateData(
        report_id=report.report_id,
        symbol=report.symbol,
        direction=direction_str,
        confidence=report.confidence,
        risk_level=report.risk_level,
        reasoning=report.summary,
        entry_logic="; ".join(entry_parts) if entry_parts else f"{report.rating} signal based on multi-agent analysis",
        exit_logic=f"Exit when conditions reverse or stoploss hit",
        suggested_indicators=indicators[:10],
        time_horizon=report.timeframe,
        can_live_trade=False,
        can_backtest=True,
        can_paper_trade=True,
        requires_human_confirm=True,
    )

    return [candidate]
