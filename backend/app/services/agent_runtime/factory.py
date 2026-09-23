"""运行时工厂 + native 兜底.

native 运行时不在此实现 — 它走 TradingAgents / Command Bus 既有链路,
handler 层按 runtime_type 分流,native 保持原行为不变。
"""
from __future__ import annotations

from app.services.agent_runtime.base import AgentRuntime
from app.services.agent_runtime.claude_code_runtime import ClaudeCodeRuntime
from app.services.agent_runtime.qoder_runtime import QoderRuntime

_RUNTIMES: dict[str, AgentRuntime] = {
    "qoder": QoderRuntime(),
    "claude-code": ClaudeCodeRuntime(),
}


def get_runtime(runtime_type: str) -> AgentRuntime | None:
    """按 runtime_type 取沙箱运行时;native 返回 None(走 Command Bus 原链路)。"""
    return _RUNTIMES.get(runtime_type)


def runtime_status() -> dict[str, dict[str, object]]:
    """所有运行时的可用性状态(供 API 展示)。"""
    out: dict[str, dict[str, object]] = {}
    for key, rt in _RUNTIMES.items():
        ok, reason = rt.available()
        out[key] = {"available": ok, "reason": reason}
    out["native"] = {"available": True, "reason": None}
    return out
