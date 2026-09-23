"""Qoder 沙箱运行时 — 封装 qoder-agent-sdk 的 query() 一次性任务."""
from __future__ import annotations

import asyncio
import logging
import time
from typing import Any

from app.services.agent_runtime.base import (
    AgentRunResult,
    AgentTaskSpec,
    PERMISSION_MAP,
)

logger = logging.getLogger(__name__)


class QoderRuntime:
    name = "qoder"

    def available(self) -> tuple[bool, str | None]:
        try:
            import qoder_agent_sdk  # noqa: F401
        except ImportError:
            return False, "qoder_agent_sdk 未安装 (pip install qoder-agent-sdk)"
        return True, None

    def run(self, spec: AgentTaskSpec) -> AgentRunResult:
        ok, reason = self.available()
        if not ok:
            return AgentRunResult(ok=False, runtime=self.name, error=reason)
        try:
            return asyncio.run(self._run_async(spec))
        except Exception as e:
            logger.exception("qoder runtime run failed")
            return AgentRunResult(ok=False, runtime=self.name, error=f"{type(e).__name__}: {e}")

    async def _run_async(self, spec: AgentTaskSpec) -> AgentRunResult:
        from qoder_agent_sdk import (
            AssistantMessage,
            QoderAgentOptions,
            ResultMessage,
            TextBlock,
            ToolUseBlock,
            query,
        )

        started = time.monotonic()
        options = QoderAgentOptions(
            system_prompt=spec.system_prompt,
            model=spec.model,
            cwd=spec.cwd,
            permission_mode=PERMISSION_MAP.get(spec.permission_mode, "plan"),
            allowed_tools=spec.allowed_tools or None,
            max_turns=spec.max_turns,
        )

        texts: list[str] = []
        tools: list[str] = []
        num_turns = 0
        async for message in query(prompt=spec.prompt, options=options):
            if isinstance(message, AssistantMessage):
                num_turns += 1
                for block in message.content:
                    if isinstance(block, TextBlock):
                        texts.append(block.text)
                    elif isinstance(block, ToolUseBlock):
                        tools.append(block.name)
            elif isinstance(message, ResultMessage):
                break

        return AgentRunResult(
            ok=True,
            runtime=self.name,
            final_text="\n".join(texts),
            tool_uses=tools,
            num_turns=num_turns,
            duration_ms=int((time.monotonic() - started) * 1000),
        )
