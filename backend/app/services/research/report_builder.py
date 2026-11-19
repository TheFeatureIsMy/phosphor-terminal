"""Build ResearchReport from LLM output.

Handles JSON parsing, validation, and degraded fallback.
"""
from __future__ import annotations

import hashlib
import json
import uuid
from datetime import datetime, timezone

import aiohttp

from app.schemas.research_v2 import AgentOpinion, ResearchReportData
from app.services.llm_service import LLMResponse, LLMService
from app.services.providers.categories.cex.binance import LIVE_REST_BASE
from app.services.research.prompt_templates import (
    RESEARCH_SYSTEM_PROMPT,
    RESEARCH_USER_PROMPT,
)
from app.services.system_trust import client_ssl_context


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
        uncertainty=1.0,
        risk_level="high",
        agent_opinions={},
        summary=f"Degraded report: {error}",
        facts=[],
        model_interpretation="",
        trading_implication="",
        risk_warning="Report generation failed; do not use for trading decisions.",
        strategy_impact="No impact assessment available due to degraded mode.",
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

    # New fields for v2.5.1 prompt
    uncertainty = float(data.get("uncertainty", 0.5))
    uncertainty = max(0.0, min(1.0, uncertainty))

    facts = data.get("facts", [])
    model_interpretation = data.get("model_interpretation", "")
    trading_implication = data.get("trading_implication", "")
    risk_warning = data.get("risk_warning", "")
    strategy_impact = data.get("strategy_impact", "")

    # evidence can be list of strings or list of dicts
    raw_evidence = data.get("evidence", [])
    evidence_strings = []
    for ev in raw_evidence:
        if isinstance(ev, str):
            evidence_strings.append(ev)
        elif isinstance(ev, dict):
            source = ev.get("source", "unknown")
            observation = ev.get("observation", "")
            evidence_strings.append(f"[{source}] {observation}")

    return ResearchReportData(
        symbol=symbol,
        market=market,
        timeframe=timeframe,
        rating=rating,
        direction=direction,
        confidence=confidence,
        uncertainty=uncertainty,
        risk_level=risk_level,
        agent_opinions=opinions,
        summary=data.get("summary", ""),
        facts=facts,
        model_interpretation=model_interpretation,
        trading_implication=trading_implication,
        risk_warning=risk_warning,
        strategy_impact=strategy_impact,
        evidence=evidence_strings,
        created_at=datetime.now(timezone.utc),
    )


def _spot_symbol(symbol: str) -> str:
    return symbol.replace("/", "").replace("-", "").upper()


def _kline_interval(timeframe: str) -> str:
    allowed = {"1m", "3m", "5m", "15m", "30m", "1h", "2h", "4h", "6h", "8h", "12h", "1d"}
    return timeframe if timeframe in allowed else "1d"


async def fetch_public_klines(symbol: str, timeframe: str) -> list:
    """Public Spot klines on the live host. No API key and no order."""
    pair = _spot_symbol(symbol)
    interval = _kline_interval(timeframe)
    url = f"{LIVE_REST_BASE}/v3/klines?symbol={pair}&interval={interval}&limit=30"
    timeout = aiohttp.ClientTimeout(total=15)
    connector = aiohttp.TCPConnector(ssl=client_ssl_context())
    async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
        async with session.get(url) as resp:
            text = await resp.text()
            if resp.status != 200:
                raise RuntimeError(f"public klines HTTP {resp.status}: {text[:120]}")
            rows = json.loads(text)
    if not isinstance(rows, list) or len(rows) < 2:
        raise RuntimeError("public klines returned no window")
    return rows


def report_from_klines(
    symbol: str,
    market: str,
    timeframe: str,
    rows: list,
) -> ResearchReportData:
    """A report whose facts are the exchange candles, not an LLM stub."""
    first_close = float(rows[0][4])
    last = rows[-1]
    last_close = float(last[4])
    change_pct = ((last_close - first_close) / first_close * 100.0) if first_close else 0.0
    pair = _spot_symbol(symbol)
    facts = [
        f"{pair} {timeframe} last close {last_close}",
        f"{pair} window first close {first_close}",
        f"{pair} change_pct {change_pct:.4f} over {len(rows)} bars",
        f"{pair} last high {last[2]} low {last[3]} volume {last[5]}",
    ]
    return ResearchReportData(
        symbol=symbol,
        market=market,
        timeframe=timeframe,
        rating="Hold",
        direction="hold",
        confidence=0.35,
        uncertainty=0.8,
        risk_level="medium",
        agent_opinions={},
        summary=(
            f"Public Binance spot {pair} {timeframe} last close {last_close}, "
            f"change {change_pct:.2f}% over {len(rows)} bars."
        ),
        facts=facts,
        model_interpretation="Facts are the public kline print. No model wrote this report.",
        trading_implication="No trade. Price history only.",
        risk_warning="Public candles are not a recommendation.",
        strategy_impact="No strategy change.",
        evidence=[f"{LIVE_REST_BASE}/v3/klines {pair} {timeframe} {len(rows)} bars"],
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
        try:
            rows = await fetch_public_klines(symbol, timeframe)
            report = report_from_klines(symbol, market, timeframe, rows)
        except Exception as market_exc:
            report = _build_degraded_report(symbol, market, timeframe, f"{exc}; market: {market_exc}")
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
