"""Generate StrategyDraft from a SignalCandidate via LLM.

Calls LLM to convert signal description into StrategyRuleDSL JSON,
then validates via DSLValidator. Never generates Python.
"""
from __future__ import annotations

from dataclasses import asdict
import hashlib
import json
import uuid
from datetime import datetime, timezone
from typing import Any

from app.schemas.research_v2 import SignalCandidateData, StrategyDraftData
from app.services.dsl_validator import DSLValidator
from app.services.llm_service import LLMResponse, LLMService
from app.services.research.prompt_templates import (
    STRATEGY_DRAFT_SYSTEM_PROMPT,
    STRATEGY_DRAFT_USER_PROMPT,
)


PYTHON_KEYWORDS = {"import ", "from ", "exec(", "eval(", "def ", "class ", "__", "subprocess", "os.system"}


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()[:32]


def _contains_python(text: str) -> bool:
    lower = text.lower()
    return any(kw in lower for kw in PYTHON_KEYWORDS)


def _build_fallback_dsl(symbol: str, direction: str) -> dict[str, Any]:
    """Minimal valid DSL as fallback when LLM output is unparseable."""
    indicator = "rsi"
    if direction in ("long", "buy"):
        entry_op, entry_val = "<", 30
        exit_op, exit_val = ">", 70
    else:
        entry_op, entry_val = ">", 70
        exit_op, exit_val = "<", 30

    return {
        "schema_version": "2.5",
        "timeframe": "1d",
        "symbols": [symbol],
        "entry": {
            "logic": "AND",
            "rules": [{
                "type": "indicator_threshold",
                "indicator": indicator,
                "params": {"period": 14},
                "operator": entry_op,
                "value": entry_val,
            }],
        },
        "exit": {
            "logic": "AND",
            "rules": [{
                "type": "indicator_threshold",
                "indicator": indicator,
                "params": {"period": 14},
                "operator": exit_op,
                "value": exit_val,
            }],
        },
        "filters": [],
        "position_sizing": {"position_pct": 0.05},
        "risk": {
            "stoploss": -0.05,
            "max_open_trades": 3,
            "trailing_stop": False,
        },
    }


async def generate_strategy_draft(
    llm_service: LLMService,
    candidate: SignalCandidateData,
    report_id: uuid.UUID,
    name_hint: str | None = None,
) -> tuple[StrategyDraftData, LLMResponse | None, str, str]:
    """Generate a StrategyDraft from a SignalCandidate.

    Returns (draft, llm_response, input_hash, output_hash).
    """
    direction_str = candidate.direction.value if hasattr(candidate.direction, 'value') else str(candidate.direction)

    user_prompt = STRATEGY_DRAFT_USER_PROMPT.format(
        symbol=candidate.symbol,
        direction=direction_str,
        entry_logic=candidate.entry_logic,
        exit_logic=candidate.exit_logic,
        suggested_indicators=", ".join(candidate.suggested_indicators),
        time_horizon=candidate.time_horizon,
    )
    input_hash = _sha256(user_prompt)

    messages = [
        {"role": "system", "content": STRATEGY_DRAFT_SYSTEM_PROMPT},
        {"role": "user", "content": user_prompt},
    ]

    rule_dsl: dict[str, Any]
    llm_response: LLMResponse | None = None
    output_hash = ""

    try:
        llm_response = await llm_service.chat(messages, temperature=0.2, max_tokens=4096)
        output_hash = _sha256(llm_response.content)

        content = llm_response.content.strip()
        if content.startswith("```"):
            lines = content.split("\n")
            lines = [l for l in lines if not l.strip().startswith("```")]
            content = "\n".join(lines)

        if _contains_python(content):
            rule_dsl = _build_fallback_dsl(candidate.symbol, direction_str)
        else:
            rule_dsl = json.loads(content)
    except Exception:
        rule_dsl = _build_fallback_dsl(candidate.symbol, direction_str)

    validator = DSLValidator()
    validation = validator.validate(rule_dsl)

    auto_name = name_hint or f"AI-{candidate.symbol}-{direction_str}-{datetime.now(timezone.utc).strftime('%Y%m%d')}"

    draft = StrategyDraftData(
        candidate_id=candidate.candidate_id,
        report_id=report_id,
        name=auto_name[:128],
        description=f"Auto-generated from AI research: {candidate.reasoning[:200]}",
        rule_dsl=rule_dsl,
        dsl_valid=validation.valid,
        dsl_errors=[asdict(e) for e in validation.errors],
        dsl_warnings=[asdict(w) for w in validation.warnings],
        source_type="ai_research",
        auto_execute=False,
        requires_human_confirm=True,
        created_at=datetime.now(timezone.utc),
    )

    return draft, llm_response, input_hash, output_hash
