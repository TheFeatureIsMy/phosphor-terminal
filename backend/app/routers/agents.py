"""Agents router — PRD §9.2 Agent Platform.

Profiles are real (shared with /api/agent-signals). Task execution goes
through the Command Bus (ADR-005): POST /{agent_id}/run enqueues a
run_agent_task command; RunAgentTaskHandler 按 runtime_type 分发到
TradingAgents(native)或 AgentRuntime 沙箱(qoder / claude-code)。
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.domain.command import CommandBusCommand
from app.domain.enums import CommandType
from app.models.agent_signal import AgentProfile
from app.services.command_bus import CommandBusService

router = APIRouter(prefix="/api/agents", tags=["agent-platform"])

RUNTIME_TYPES = ("native", "qoder", "claude-code")
PERMISSION_MODES = ("readonly", "approval", "auto")
TRIGGER_TYPES = ("manual", "schedule", "event")
OUTPUT_TARGETS = ("inbox", "signals", "growth")


class AgentRunRequest(BaseModel):
    symbol: str = "BTC/USDT"
    analysis_date: str | None = None
    asset_type: str = "crypto"
    prompt: str | None = None  # 沙箱运行时自定义任务描述
    selected_analysts: list[str] = Field(default_factory=lambda: ["market", "social", "news"])
    llm_provider: str = "ollama"
    deep_think_llm: str = "qwen2.5:14b"
    quick_think_llm: str = "qwen2.5:7b"


class AgentUpsertRequest(BaseModel):
    name: str
    kind: str = "research"
    description: str | None = None
    runtime_type: str = "native"
    model: str | None = None
    cwd: str | None = None
    permission_mode: str = "readonly"
    allowed_tools: list[str] = Field(default_factory=list)
    max_turns: int = Field(default=20, ge=1, le=200)
    trigger_type: str = "manual"
    output_target: str = "inbox"
    system_prompt: str | None = None

    def validate_enums(self):
        if self.runtime_type not in RUNTIME_TYPES:
            raise HTTPException(422, f"runtime_type 必须是 {RUNTIME_TYPES}")
        if self.permission_mode not in PERMISSION_MODES:
            raise HTTPException(422, f"permission_mode 必须是 {PERMISSION_MODES}")
        if self.trigger_type not in TRIGGER_TYPES:
            raise HTTPException(422, f"trigger_type 必须是 {TRIGGER_TYPES}")
        if self.output_target not in OUTPUT_TARGETS:
            raise HTTPException(422, f"output_target 必须是 {OUTPUT_TARGETS}")


def _profile_dict(p: AgentProfile) -> dict:
    return {
        "id": p.id,
        "name": p.name,
        "kind": p.kind,
        "status": p.status,
        "description": p.description,
        "runtime_type": p.runtime_type,
        "model": p.model,
        "cwd": p.cwd,
        "permission_mode": p.permission_mode,
        "allowed_tools": p.allowed_tools or [],
        "max_turns": p.max_turns,
        "trigger_type": p.trigger_type,
        "output_target": p.output_target,
        "system_prompt": p.system_prompt,
        "last_heartbeat_at": p.last_heartbeat_at.isoformat() if p.last_heartbeat_at else None,
        "created_at": p.created_at.isoformat() if p.created_at else None,
    }


@router.get("")
def list_agents(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    profiles = (
        db.query(AgentProfile)
        .order_by(AgentProfile.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return {
        "state": "healthy",
        "reason_codes": [],
        "available_actions": [],
        "agents": [_profile_dict(p) for p in profiles],
        "total": len(profiles),
    }


@router.get("/runtimes")
def get_runtimes():
    """各沙箱运行时的可用性(SDK/CLI 是否就绪)。"""
    from app.services.agent_runtime import runtime_status

    return {"runtimes": runtime_status()}


@router.get("/tasks")
def list_agent_tasks(
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """Agent task queue — run_agent_task commands from the Command Bus."""
    commands = list(db.scalars(
        select(CommandBusCommand)
        .where(CommandBusCommand.command_type == CommandType.RUN_AGENT_TASK.value)
        .order_by(CommandBusCommand.created_at.desc())
        .limit(limit)
    ).all())
    return {
        "state": "healthy",
        "reason_codes": [],
        "available_actions": [],
        "tasks": [
            {
                "task_id": str(c.id),
                "agent_id": (c.payload or {}).get("agent_id"),
                "runtime_type": (c.payload or {}).get("runtime_type", "native"),
                "symbol": (c.payload or {}).get("symbol"),
                "status": c.status,
                "error_code": c.error_code,
                "error_message": c.error_message,
                "created_at": c.created_at.isoformat() if c.created_at else None,
                "completed_at": c.completed_at.isoformat() if c.completed_at else None,
            }
            for c in commands
        ],
        "total": len(commands),
    }


@router.get("/{agent_id}")
def get_agent(agent_id: int, db: Session = Depends(get_db)):
    profile = db.get(AgentProfile, agent_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Agent not found")
    return _profile_dict(profile)


@router.post("", status_code=201)
def create_agent(req: AgentUpsertRequest, db: Session = Depends(get_db)):
    req.validate_enums()
    exists = db.scalar(select(AgentProfile).where(AgentProfile.name == req.name))
    if exists:
        raise HTTPException(status_code=409, detail="同名 Agent 已存在")
    profile = AgentProfile(
        name=req.name,
        kind=req.kind,
        description=req.description,
        runtime_type=req.runtime_type,
        model=req.model,
        cwd=req.cwd,
        permission_mode=req.permission_mode,
        allowed_tools=req.allowed_tools,
        max_turns=req.max_turns,
        trigger_type=req.trigger_type,
        output_target=req.output_target,
        system_prompt=req.system_prompt,
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return _profile_dict(profile)


@router.put("/{agent_id}")
def update_agent(agent_id: int, req: AgentUpsertRequest, db: Session = Depends(get_db)):
    req.validate_enums()
    profile = db.get(AgentProfile, agent_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Agent not found")
    for field_name in (
        "name", "kind", "description", "runtime_type", "model", "cwd",
        "permission_mode", "allowed_tools", "max_turns", "trigger_type",
        "output_target", "system_prompt",
    ):
        setattr(profile, field_name, getattr(req, field_name))
    db.commit()
    db.refresh(profile)
    return _profile_dict(profile)


@router.delete("/{agent_id}")
def delete_agent(agent_id: int, db: Session = Depends(get_db)):
    profile = db.get(AgentProfile, agent_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Agent not found")
    profile.status = "archived"
    db.commit()
    return {"state": "healthy", "archived_id": agent_id}


@router.post("/{agent_id}/run", status_code=202)
def run_agent(
    agent_id: int,
    req: AgentRunRequest = AgentRunRequest(),
    db: Session = Depends(get_db),
):
    """Enqueue an agent task; execution happens in the Command Bus worker."""
    profile = db.get(AgentProfile, agent_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Agent not found")

    analysis_date = req.analysis_date or datetime.now(timezone.utc).date().isoformat()
    idempotency_key = (
        f"run_agent_task:{agent_id}:{req.symbol}:{analysis_date}:"
        f"{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"
    )

    bus = CommandBusService(db)
    cmd, created = bus.enqueue(
        command_type=CommandType.RUN_AGENT_TASK.value,
        aggregate_type="agent_profile",
        payload={
            "agent_id": agent_id,
            "agent_name": profile.name,
            "symbol": req.symbol,
            "analysis_date": analysis_date,
            "asset_type": req.asset_type,
            "prompt": req.prompt,
            # 运行时配置随任务携带,handler 无需再查库
            "runtime_type": profile.runtime_type,
            "model": profile.model,
            "cwd": profile.cwd,
            "permission_mode": profile.permission_mode,
            "allowed_tools": profile.allowed_tools or [],
            "max_turns": profile.max_turns,
            "system_prompt": profile.system_prompt,
            # native 链路参数
            "selected_analysts": req.selected_analysts,
            "llm_provider": req.llm_provider,
            "deep_think_llm": req.deep_think_llm,
            "quick_think_llm": req.quick_think_llm,
        },
        idempotency_key=idempotency_key,
        requested_by=f"api:agents/{agent_id}/run",
        timeout_sec=900,
    )
    db.commit()
    db.refresh(cmd)

    return {
        "state": "running",
        "reason_codes": [],
        "available_actions": [
            {"type": "cancel_task", "enabled": True, "label": "取消任务"},
        ],
        "task_id": str(cmd.id),
        "status": cmd.status,
        "message": "agent task enqueued" if created else "task already exists",
    }


@router.post("/tasks/{task_id}/cancel")
def cancel_agent_task(task_id: str, db: Session = Depends(get_db)):
    """Cancel a queued agent task (Command Bus cancel semantics)."""
    try:
        command_id = uuid.UUID(task_id)
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid task id")

    cmd = db.get(CommandBusCommand, command_id)
    if cmd is None or cmd.command_type != CommandType.RUN_AGENT_TASK.value:
        raise HTTPException(status_code=404, detail="Agent task not found")

    bus = CommandBusService(db)
    ok, reason = bus.cancel(command_id)
    db.commit()
    if not ok:
        raise HTTPException(status_code=409, detail={
            "state": "blocked",
            "reason_codes": [f"cancel_{reason}"],
        })
    return {"state": "healthy", "reason_codes": [], "cancelled_task_id": task_id}
