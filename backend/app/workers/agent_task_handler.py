"""RunAgentTaskHandler — 按 runtime_type 分发到对应沙箱运行时.

runtime_type = native:走 TradingAgents adapter(原行为不变);
runtime_type = qoder / claude-code:走 AgentRuntime 沙箱实例
(qoder-agent-sdk / claude-agent-sdk 的 query() 一次性任务)。
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.workers.handlers import CommandHandler

logger = logging.getLogger(__name__)


class RunAgentTaskHandler(CommandHandler):
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload or {}
        runtime_type = payload.get("runtime_type", "native")

        if runtime_type != "native":
            return self._run_sandbox(payload, runtime_type)
        return self._run_native(payload)

    # ---- 沙箱运行时(Qoder / Claude Code) ----

    def _run_sandbox(self, payload: dict[str, Any], runtime_type: str) -> dict[str, Any]:
        from app.services.agent_runtime import AgentTaskSpec, get_runtime

        runtime = get_runtime(runtime_type)
        if runtime is None:
            return {"agent_id": payload.get("agent_id"), "ok": False,
                    "error": f"unknown runtime: {runtime_type}"}

        spec = AgentTaskSpec(
            prompt=payload.get("prompt") or self._default_prompt(payload),
            runtime_type=runtime_type,
            model=payload.get("model"),
            cwd=payload.get("cwd"),
            permission_mode=payload.get("permission_mode", "readonly"),
            allowed_tools=payload.get("allowed_tools") or [],
            max_turns=payload.get("max_turns", 20),
            system_prompt=payload.get("system_prompt"),
        )
        result = runtime.run(spec)
        return {
            "agent_id": payload.get("agent_id"),
            "runtime": result.runtime,
            "ok": result.ok,
            "error": result.error,
            "final_text": result.final_text[:4000],
            "tool_uses": result.tool_uses[:50],
            "num_turns": result.num_turns,
            "duration_ms": result.duration_ms,
        }

    @staticmethod
    def _default_prompt(payload: dict[str, Any]) -> str:
        symbol = payload.get("symbol", "BTC/USDT")
        analysis_date = payload.get(
            "analysis_date", datetime.now(timezone.utc).date().isoformat(),
        )
        return f"分析 {symbol} 在 {analysis_date} 的市场结构并给出交易观点。"

    # ---- 原生 TradingAgents 链路 ----

    def _run_native(self, payload: dict[str, Any]) -> dict[str, Any]:
        symbol = payload.get("symbol", "BTC/USDT")
        analysis_date = payload.get(
            "analysis_date", datetime.now(timezone.utc).date().isoformat(),
        )
        asset_type = payload.get("asset_type", "crypto")
        selected_analysts = payload.get(
            "selected_analysts", ["market", "social", "news"],
        )

        from app.services.tradingagents_adapter import (
            TradingAgentsConfig,
            run_tradingagents_analysis,
        )

        config = TradingAgentsConfig(
            llm_provider=payload.get("llm_provider", "ollama"),
            deep_think_llm=payload.get("deep_think_llm", "qwen2.5:14b"),
            quick_think_llm=payload.get("quick_think_llm", "qwen2.5:7b"),
            max_debate_rounds=payload.get("max_debate_rounds", 1),
            max_risk_rounds=payload.get("max_risk_rounds", 1),
        )

        result = run_tradingagents_analysis(
            symbol=symbol,
            analysis_date=analysis_date,
            asset_type=asset_type,
            selected_analysts=selected_analysts,
            config=config,
        )

        return {
            "agent_id": payload.get("agent_id"),
            "symbol": symbol,
            "rating": result.get("rating"),
            "has_decision": result.get("processed_decision") is not None,
        }
