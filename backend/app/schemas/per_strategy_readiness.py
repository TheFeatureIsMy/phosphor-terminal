"""PerStrategyReadiness — 6 per-strategy gates + 5 system gates + grand_status + next_action

Spec: docs/superpowers/specs/2026-06-17-strategy-workbench-canvas-first-design.md §6.4
"""
from __future__ import annotations

from pydantic import BaseModel, Field


class ReadinessGate(BaseModel):
    """Single readiness check (strategy or system)."""
    key: str
    status: str = "unknown"  # healthy | warning | failed | unknown
    value: str = ""
    threshold: str = ""
    detail: str = ""
    reason_codes: list[str] = Field(default_factory=list)


class ReadinessNextAction(BaseModel):
    """What the user should do next to progress the readiness gate."""
    code: str = "none"       # gate-specific code
    label: str = ""          # human-readable hint
    target_panel: str | None = None  # "risk" | "backtest" | "readiness" | None


class PerStrategyReadinessResponse(BaseModel):
    """Full readiness snapshot for a single strategy (11 gates total)."""
    passed_count: int = 0           # 0..11
    total: int = 11
    grand_status: str = "not_live"  # not_live | needs_config | needs_validation | paper_passed | ready_for_live
    next_action: ReadinessNextAction = Field(default_factory=ReadinessNextAction)
    strategy_gates: list[ReadinessGate] = Field(default_factory=list)
    system_gates: list[ReadinessGate] = Field(default_factory=list)
