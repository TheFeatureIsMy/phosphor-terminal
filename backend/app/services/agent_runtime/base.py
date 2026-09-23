"""AgentRuntime 抽象层 — 统一 Qoder / Claude Code / native 运行时.

把"沙箱 agent 实例"抽象为统一接口:运行时负责把 AgentProfile 配置
翻译成 SDK 的 Options,执行 prompt 并收敛消息流为结构化结果。
SDK 未安装时优雅降级为 sdk_unavailable,不影响平台其他链路。
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass
class AgentTaskSpec:
    """一次 agent 运行的完整输入."""

    prompt: str
    runtime_type: str = "native"
    model: str | None = None
    cwd: str | None = None
    permission_mode: str = "readonly"  # readonly | approval | auto
    allowed_tools: list[str] = field(default_factory=list)
    max_turns: int = 20
    system_prompt: str | None = None


@dataclass
class AgentRunResult:
    """运行结果:最终文本 + 工具活动摘要 + 用量."""

    ok: bool
    runtime: str
    final_text: str = ""
    tool_uses: list[str] = field(default_factory=list)  # 工具名序列
    num_turns: int = 0
    duration_ms: int = 0
    error: str | None = None


class AgentRuntime(Protocol):
    """沙箱运行时协议。"""

    name: str

    def available(self) -> tuple[bool, str | None]:
        """(可用性, 不可用原因)。SDK 缺失/CLI 缺失时返回 False。"""
        ...

    def run(self, spec: AgentTaskSpec) -> AgentRunResult:
        """同步执行一次任务,收敛完整消息流后返回结果。"""
        ...


# permission_mode 到各 SDK PermissionMode 的映射
PERMISSION_MAP = {
    "readonly": "plan",        # 只读规划模式:agent 不能改文件/跑命令
    "approval": "default",     # 默认:危险操作触发 can_use_tool 回调
    "auto": "bypassPermissions",
}
