"""Canvas AI generation — natural language → StrategyRuleDSL.

Takes a conversational prompt, calls the LLM to produce a StrategyRuleDSL
JSON, validates via DSLValidator, and returns the DSL + validation report.
Never generates Python. Falls back to a minimal valid DSL on parse failure.
"""
from __future__ import annotations

import json
import logging
from typing import Any

from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.services.dsl_validator import DSLValidator
from app.services.llm_service import create_llm_service_from_env

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/canvas", tags=["canvas-ai"])

_SYSTEM_PROMPT = """You are a quant strategy DSL generator. Convert the user's natural-language
trading strategy description into a valid StrategyRuleDSL JSON object (schema_version "2.5").

The DSL MUST have this exact shape:
{
  "schema_version": "2.5",
  "timeframe": "1d",
  "symbols": ["BTC/USDT"],
  "entry": { "logic": "AND", "rules": [ { "type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": "<", "value": 30 } ] },
  "exit":  { "logic": "AND", "rules": [ { "type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14}, "operator": ">", "value": 70 } ] },
  "filters": [],
  "position_sizing": { "position_pct": 0.05 },
  "risk": { "stoploss": -0.05, "max_open_trades": 3, "trailing_stop": false }
}

Allowed indicators: rsi, macd, ema, sma, bollinger, atr, stochastic, adx, obv, vwap, roc, cci, willr, momentum.
Allowed operators: <, >, <=, >=, ==, !=, crosses_above, crosses_below.
Allowed filter types: manipulation_score, min_volume, max_spread, min_confidence, regime_filter.

Rules:
- Respond ONLY with the JSON object. No prose, no markdown fences, no Python.
- Use the user's described indicators/thresholds where clear; otherwise pick sensible RSI defaults.
- entry logic for long bias: buy on oversold; exit on overbought. For short bias invert.
"""


class CanvasAIGenerateRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=4000)
    symbol: str = "BTC/USDT"


def _build_fallback_dsl(symbol: str) -> dict[str, Any]:
    return {
        "schema_version": "2.5",
        "timeframe": "1d",
        "symbols": [symbol],
        "entry": {"logic": "AND", "rules": [{
            "type": "indicator_threshold", "indicator": "rsi",
            "params": {"period": 14}, "operator": "<", "value": 30,
        }]},
        "exit": {"logic": "AND", "rules": [{
            "type": "indicator_threshold", "indicator": "rsi",
            "params": {"period": 14}, "operator": ">", "value": 70,
        }]},
        "filters": [],
        "position_sizing": {"position_pct": 0.05},
        "risk": {"stoploss": -0.05, "max_open_trades": 3, "trailing_stop": False},
    }


@router.post("/ai-generate")
async def ai_generate(body: CanvasAIGenerateRequest):
    """Generate a StrategyRuleDSL from natural language."""
    rule_dsl: dict[str, Any]
    llm_error: str | None = None

    try:
        llm = create_llm_service_from_env()
        messages = [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": f"Strategy for {body.symbol}:\n{body.prompt}"},
        ]
        resp = await llm.chat(messages, temperature=0.2, max_tokens=4096)
        content = resp.content.strip()
        if content.startswith("```"):
            lines = [l for l in content.split("\n") if not l.strip().startswith("```")]
            content = "\n".join(lines)
        rule_dsl = json.loads(content)
    except Exception as exc:  # noqa: BLE001 — LLM/parse failure falls back
        logger.warning("[canvas-ai] LLM generation failed, using fallback: %s", exc)
        llm_error = str(exc)[:200]
        rule_dsl = _build_fallback_dsl(body.symbol)

    validation = DSLValidator().validate(rule_dsl)

    return {
        "dsl": rule_dsl,
        "valid": validation.valid,
        "error_count": validation.error_count,
        "warning_count": validation.warning_count,
        "errors": [
            {"code": e.code, "path": e.path, "message": e.message, "severity": e.severity}
            for e in validation.errors
        ],
        "warnings": [
            {"code": w.code, "path": w.path, "message": w.message, "severity": w.severity}
            for w in validation.warnings
        ],
        "llm_error": llm_error,
    }