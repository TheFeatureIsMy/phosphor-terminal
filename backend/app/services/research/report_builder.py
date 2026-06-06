"""Build ResearchReport from LLM output.

Handles JSON parsing, validation, and degraded fallback.
"""
from __future__ import annotations

import hashlib
import json
import uuid
from datetime import datetime, timezone

from app.schemas.research_v2 import AgentOpinion, ResearchReportData
from app.services.llm_service import LLMResponse, LLMService
from app.services.research.prompt_templates import (
    RESEARCH_SYSTEM_PROMPT,
    RESEARCH_USER_PROMPT,
)


VALID_RATINGS = {"Buy", "Overweight", "Hold", "Underweight", "Sell"}
VALID_DIRECTIONS = {"long", "short", "hold", "risk"}
VALID_RISK_LEVELS = {"low", "medium", "high", "extreme"}


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()[:32]


def _build_degraded_report(symbol: str, market: str, timeframe: str, error: str) -> ResearchReportData:
    return ResearchReportData(
        symbol=symbol,
        market=market,
        timeframe=timeframe,
        rating="Hold",
        direction="hold",
        confidence=0.0,
        risk_level="high",
        agent_opinions={},
        summary=f"Degraded report: {error}",
        evidence=[],
        created_at=datetime.now(timezone.utc),
    )


def _parse_report_json(raw: str, symbol: str, market: str, timeframe: str) -> ResearchReportData:
    data = json.loads(raw)

    rating = data.get("rating", "Hold")
    if rating not in VALID_RATINGS:
        rating = "Hold"

    direction = data.get("direction", "hold")
    if direction not in VALID_DIRECTIONS:
        direction = "hold"

    risk_level = data.get("risk_level", "medium")
    if risk_level not in VALID_RISK_LEVELS:
        risk_level = "medium"

    confidence = float(data.get("confidence", 0.0))
    confidence = max(0.0, min(1.0, confidence))

    opinions: dict[str, AgentOpinion] = {}
    raw_opinions = data.get("agent_opinions", {})
    if isinstance(raw_opinions, dict):
        for role, opinion_data in raw_opinions.items():
            if isinstance(opinion_data, dict):
                opinions[role] = AgentOpinion(
                    role=opinion_data.get("role", role),
                    stance=opinion_data.get("stance", "neutral"),
                    reasoning=opinion_data.get("reasoning", ""),
                    confidence=max(0.0, min(1.0, float(opinion_data.get("confidence", 0.5)))),
                    key_factors=opinion_data.get("key_factors", []),
                )

    return ResearchReportData(
        symbol=symbol,
        market=market,
        timeframe=timeframe,
        rating=rating,
        direction=direction,
        confidence=confidence,
        risk_level=risk_level,
        agent_opinions=opinions,
        summary=data.get("summary", ""),
        evidence=data.get("evidence", []),
        created_at=datetime.now(timezone.utc),
    )


async def build_research_report(
    llm_service: LLMService,
    symbol: str,
    market: str,
    timeframe: str,
    analysis_date: str,
    selected_analysts: list[str],
) -> tuple[ResearchReportData, LLMResponse | None, str, str]:
    """Run LLM research and return (report, llm_response, input_hash, output_hash).

    Returns degraded report on failure; never raises.
    """
    user_prompt = RESEARCH_USER_PROMPT.format(
        symbol=symbol,
        market=market,
        timeframe=timeframe,
        analysis_date=analysis_date,
        analysts=", ".join(selected_analysts),
    )
    input_hash = _sha256(user_prompt)

    messages = [
        {"role": "system", "content": RESEARCH_SYSTEM_PROMPT},
        {"role": "user", "content": user_prompt},
    ]

    try:
        llm_response = await llm_service.chat(messages, temperature=0.3, max_tokens=4096)
    except Exception as exc:
        report = _build_degraded_report(symbol, market, timeframe, str(exc))
        return report, None, input_hash, ""

    output_hash = _sha256(llm_response.content)

    try:
        content = llm_response.content.strip()
        if content.startswith("```"):
            lines = content.split("\n")
            lines = [l for l in lines if not l.strip().startswith("```")]
            content = "\n".join(lines)
        report = _parse_report_json(content, symbol, market, timeframe)
    except (json.JSONDecodeError, KeyError, ValueError) as exc:
        report = _build_degraded_report(symbol, market, timeframe, f"JSON parse error: {exc}")

    return report, llm_response, input_hash, output_hash
