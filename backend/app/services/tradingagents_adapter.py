from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any


VALID_RATINGS = {"Buy", "Overweight", "Hold", "Underweight", "Sell"}


@dataclass
class TradingAgentsConfig:
    llm_provider: str = "openai"
    deep_think_llm: str = "gpt-5.4"
    quick_think_llm: str = "gpt-5.4-mini"
    max_debate_rounds: int = 1
    max_risk_rounds: int = 1
    output_language: str = "English"

    def to_tradingagents_config(self) -> dict[str, Any]:
        return {
            "llm_provider": self.llm_provider,
            "deep_think_llm": self.deep_think_llm,
            "quick_think_llm": self.quick_think_llm,
            "max_debate_rounds": self.max_debate_rounds,
            "max_risk_discuss_rounds": self.max_risk_rounds,
            "checkpoint_enabled": True,
            "output_language": self.output_language,
        }


def extract_rating(final_decision: str | None) -> str | None:
    if not final_decision:
        return None
    match = re.search(r"\*\*Rating\*\*\s*:\s*(Buy|Overweight|Hold|Underweight|Sell)", final_decision)
    if match:
        return match.group(1)
    for rating in VALID_RATINGS:
        if re.search(rf"\b{rating}\b", final_decision):
            return rating
    return None


def normalize_tradingagents_state(state: dict[str, Any]) -> dict[str, Any]:
    final_decision = state.get("final_trade_decision") or ""
    return {
        "rating": extract_rating(final_decision),
        "final_decision": final_decision,
        "market_report": state.get("market_report"),
        "sentiment_report": state.get("sentiment_report"),
        "news_report": state.get("news_report"),
        "fundamentals_report": state.get("fundamentals_report"),
        "investment_debate": state.get("investment_debate_state") or {},
        "risk_debate": state.get("risk_debate_state") or {},
    }


def run_tradingagents_analysis(
    symbol: str,
    analysis_date: str,
    asset_type: str,
    selected_analysts: list[str],
    config: TradingAgentsConfig,
) -> dict[str, Any]:
    from tradingagents.default_config import DEFAULT_CONFIG
    from tradingagents.graph.trading_graph import TradingAgentsGraph

    runtime_config = DEFAULT_CONFIG.copy()
    runtime_config.update(config.to_tradingagents_config())

    graph = TradingAgentsGraph(
        selected_analysts=selected_analysts,
        debug=False,
        config=runtime_config,
    )
    state, decision = graph.propagate(symbol, analysis_date, asset_type=asset_type)
    normalized = normalize_tradingagents_state(state)
    normalized["processed_decision"] = decision
    return normalized
