"""
RAG Strategy Lab service.
Provides PDF parsing, knowledge retrieval, and strategy generation.
Uses LLM when available, falls back to template matching.
"""
from __future__ import annotations
import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)

# Lazy-initialized LLM service singleton
_llm_service = None
_llm_service_initialized = False


def _get_llm_service():
    """Return the LLM service if available, None otherwise. Initialized once."""
    global _llm_service, _llm_service_initialized
    if _llm_service_initialized:
        return _llm_service
    _llm_service_initialized = True
    try:
        from app.services.llm_service import create_llm_service_from_env
        _llm_service = create_llm_service_from_env()
        if not _llm_service.providers:
            logger.info("No LLM providers configured; RAG will use template fallback")
            _llm_service = None
    except Exception as exc:
        logger.warning("Failed to initialize LLM service: %s", exc)
        _llm_service = None
    return _llm_service


def _reset_llm_service():
    """Reset the cached LLM service (for testing)."""
    global _llm_service, _llm_service_initialized
    _llm_service = None
    _llm_service_initialized = False


def parse_pdf_content(text: str, filename: str) -> dict[str, Any]:
    """
    Extract trading-relevant knowledge from PDF text.
    In production, would use actual PDF parser + NLP.
    """
    concepts = []
    lines = text.split('\n')
    for line in lines:
        line = line.strip()
        if len(line) > 20 and any(kw in line.lower() for kw in ['strategy', 'trading', 'signal', 'indicator', 'risk', 'position']):
            concepts.append(line[:200])

    doc_id = hashlib.md5(f"{filename}:{text[:100]}".encode()).hexdigest()[:12]

    return {
        "doc_id": doc_id,
        "filename": filename,
        "concepts_extracted": len(concepts),
        "chunks_created": max(1, len(concepts) // 3),
    }


async def generate_strategy(
    prompt: str,
    risk_level: str = "medium",
    market: str = "crypto",
    context: list[dict] | None = None,
) -> dict[str, Any]:
    """
    Generate a trading strategy based on prompt and knowledge base.
    Tries LLM first, falls back to template matching if unavailable.
    """
    llm = _get_llm_service()
    if llm is not None:
        try:
            return await _generate_strategy_via_llm(llm, prompt, risk_level, market, context)
        except Exception as exc:
            logger.warning("LLM strategy generation failed, falling back to template: %s", exc)

    return _generate_strategy_from_template(prompt, risk_level, market, context)


async def _generate_strategy_via_llm(
    llm,
    prompt: str,
    risk_level: str,
    market: str,
    context: list[dict] | None,
) -> dict[str, Any]:
    """Use LLM to generate a strategy. Raises on failure so caller can fall back."""
    context_text = ""
    if context:
        context_text = "\n".join(
            f"- [{c.get('filename', 'unknown')}] {c.get('content', '')[:200]}"
            for c in context[:5]
        )

    system_msg = (
        "You are a quantitative trading strategy expert. "
        "Generate a Freqtrade-compatible trading strategy in JSON format. "
        "Respond ONLY with valid JSON, no markdown fences, no extra text."
    )

    context_block = ("Knowledge base context:" + chr(10) + context_text) if context_text else ""

    user_msg = (
        f'Generate a trading strategy based on this request:\n'
        f'"{prompt}"\n\n'
        f'Risk level: {risk_level}\n'
        f'Market: {market}\n'
        f'{context_block}\n\n'
        f'Respond with this exact JSON structure:\n'
        f'{{\n'
        f'  "name": "策略中文名称",\n'
        f'  "type": "one of: ma_cross, breakout, mean_reversion, rsi, macd, bollinger",\n'
        f'  "parameters": {{\n'
        f'    "key1": value1,\n'
        f'    "key2": value2\n'
        f'  }},\n'
        f'  "explanation": "中文解释，说明策略逻辑和为什么适合用户需求"\n'
        f'}}\n\n'
        f'Parameters should be numeric values suitable for a Freqtrade strategy class.'
    )

    response = await llm.chat(
        messages=[
            {"role": "system", "content": system_msg},
            {"role": "user", "content": user_msg},
        ],
        temperature=0.7,
        max_tokens=1024,
    )

    parsed = _parse_llm_strategy_json(response.content)
    template = {
        "name": parsed["name"],
        "type": parsed["type"],
        "parameters": parsed["parameters"],
    }

    code = _generate_strategy_code(template, risk_level, market)

    return {
        "strategy": {
            **template,
            "market": market,
            "source": "llm_generated",
            "model": response.model,
            "provider": response.provider,
        },
        "code": code,
        "context_used": context,
        "risk_level": risk_level,
        "explanation": parsed.get("explanation", f"LLM 生成了{template['name']}。"),
    }


def _parse_llm_strategy_json(content: str) -> dict:
    """Parse LLM response into strategy dict. Raises ValueError on bad JSON."""
    # Strip markdown fences if present
    text = content.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        # Remove first and last fence lines
        lines = [l for l in lines if not l.strip().startswith("```")]
        text = "\n".join(lines)

    parsed = json.loads(text)

    # Validate required fields
    if not isinstance(parsed.get("name"), str):
        raise ValueError("LLM response missing 'name' string")
    if not isinstance(parsed.get("type"), str):
        raise ValueError("LLM response missing 'type' string")
    if not isinstance(parsed.get("parameters"), dict):
        raise ValueError("LLM response missing 'parameters' dict")

    return parsed


def _generate_strategy_from_template(
    prompt: str,
    risk_level: str,
    market: str,
    context: list[dict] | None,
) -> dict[str, Any]:
    """Template-based strategy generation (fallback when no LLM available)."""
    strategy_templates = {
        "ma_cross": {
            "name": "MA交叉策略",
            "type": "ma_cross",
            "parameters": {
                "fast_period": 10,
                "slow_period": 30,
                "signal_threshold": 0.001,
            },
        },
        "breakout": {
            "name": "突破策略",
            "type": "breakout",
            "parameters": {
                "lookback_period": 20,
                "breakout_threshold": 0.02,
                "volume_confirmation": True,
            },
        },
        "mean_reversion": {
            "name": "均值回归策略",
            "type": "mean_reversion",
            "parameters": {
                "z_score_threshold": 2.0,
                "lookback_period": 50,
                "exit_z_score": 0.5,
            },
        },
    }

    # Select template based on prompt keywords
    prompt_lower = prompt.lower()
    if "break" in prompt_lower or "突破" in prompt_lower:
        template = strategy_templates["breakout"]
    elif "mean" in prompt_lower or "回归" in prompt_lower:
        template = strategy_templates["mean_reversion"]
    else:
        template = strategy_templates["ma_cross"]

    # Generate Python code
    code = _generate_strategy_code(template, risk_level, market)

    return {
        "strategy": {
            **template,
            "market": market,
            "source": "rag_generated",
        },
        "code": code,
        "context_used": context,
        "risk_level": risk_level,
        "explanation": f"基于您的描述「{prompt}」，生成了{template['name']}。"
            + (f"参考了 {len(context)} 条知识库内容。" if context else "使用了默认模板。"),
    }


def _generate_strategy_code(template: dict, risk_level: str, market: str) -> str:
    """Generate Python strategy code."""
    params = template["parameters"]
    risk_params = {
        "low": {"stop_loss": 0.02, "take_profit": 0.04, "position_size": 0.1},
        "medium": {"stop_loss": 0.03, "take_profit": 0.06, "position_size": 0.2},
        "high": {"stop_loss": 0.05, "take_profit": 0.10, "position_size": 0.3},
    }
    risk = risk_params.get(risk_level, risk_params["medium"])

    return f'''"""
{template["name"]} - RAG Generated
Market: {market}
Risk Level: {risk_level}
Generated: {datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M")}
"""

from freqtrade.strategy import IStrategy, merge_informative_pair
from pandas import DataFrame
import talib.abstract as ta


class RAG{template["type"].title().replace("_", "")}Strategy(IStrategy):
    """
    {template["name"]}
    Auto-generated by PulseDesk RAG Strategy Lab
    """

    INTERFACE_VERSION = 3

    # Timeframe
    timeframe = "1h"

    # Risk parameters
    stop_loss = {risk["stop_loss"]}
    take_profit = {risk["take_profit"]}
    position_adjustment_enable = False

    # Strategy parameters
{chr(10).join(f"    {k} = {repr(v)}" for k, v in params.items())}

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """Calculate indicators."""
        # Add your indicators here
        dataframe["ema_fast"] = ta.EMA(dataframe, timeperiod={params.get("fast_period", 10)})
        dataframe["ema_slow"] = ta.EMA(dataframe, timeperiod={params.get("slow_period", 30)})
        dataframe["rsi"] = ta.RSI(dataframe, timeperiod=14)

        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """Define entry signals."""
        dataframe.loc[
            (
                (dataframe["ema_fast"] > dataframe["ema_slow"]) &
                (dataframe["rsi"] < 70) &
                (dataframe["volume"] > 0)
            ),
            "enter_long",
        ] = 1

        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """Define exit signals."""
        dataframe.loc[
            (
                (dataframe["ema_fast"] < dataframe["ema_slow"]) |
                (dataframe["rsi"] > 80)
            ),
            "exit_long",
        ] = 1

        return dataframe
'''



