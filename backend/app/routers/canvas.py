"""Canvas router — PRD §5.2 策略画布 compile / save-draft / publish / templates.

The graph → DSL compilation itself runs in the canvas-web frontend
(converters/graphToDsl.ts); this router is the authoritative backend gate:
it validates compiled DSL, persists canvas drafts, and promotes validated
DSL into StrategyVersion drafts. Canvas never executes anything directly.
"""
from __future__ import annotations

import uuid
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.security.deps import get_current_tenant_id
from app.domain.strategy import CanvasDraft, StrategyVersion
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash
from app.services.dsl_validator import DSLValidator

router = APIRouter(prefix="/api/canvas", tags=["canvas"])

_validator = DSLValidator()


# ── Schemas ───────────────────────────────────────────────────────────

class CanvasCompileRequest(BaseModel):
    dsl: dict[str, Any]
    graph: dict[str, Any] = Field(default_factory=dict)


class CanvasDraftRequest(BaseModel):
    strategy_id: uuid.UUID
    graph: dict[str, Any]
    dsl: Optional[dict[str, Any]] = None
    updated_by: str = "canvas"


class CanvasPublishRequest(BaseModel):
    strategy_id: uuid.UUID
    dsl: dict[str, Any]
    graph: dict[str, Any] = Field(default_factory=dict)
    created_by: str = "canvas"


# ── Templates ─────────────────────────────────────────────────────────

def _template(name: str, description: str, entry_rules: list[dict], exit_rules: list[dict]) -> dict:
    return {
        "name": name,
        "description": description,
        "dsl": {
            "schema_version": "2.5",
            "timeframe": "1h",
            "symbols": ["BTC/USDT"],
            "entry": {"logic": "AND", "rules": entry_rules},
            "exit": {"logic": "OR", "rules": exit_rules},
            "filters": [],
            "position_sizing": {"position_pct": 0.05},
            "risk": {"stoploss": -0.05, "max_open_trades": 3, "trailing_stop": False},
        },
    }


CANVAS_TEMPLATES: list[dict] = [
    _template(
        name="RSI Mean Reversion",
        description="RSI 超卖入场 / 超买出场的均值回归模板",
        entry_rules=[{"type": "indicator_threshold", "indicator": "rsi", "operator": "<",
                      "value": 30, "params": {"period": 14}}],
        exit_rules=[{"type": "indicator_threshold", "indicator": "rsi", "operator": ">",
                     "value": 70, "params": {"period": 14}}],
    ),
    _template(
        name="EMA Trend Follow",
        description="EMA 快线上穿慢线入场 / 下穿出场的趋势跟踪模板",
        entry_rules=[{"type": "indicator_cross", "indicator": "ema",
                      "params": {"period": 12}, "cross_indicator": "ema",
                      "cross_params": {"period": 26}, "direction": "crosses_above"}],
        exit_rules=[{"type": "indicator_cross", "indicator": "ema",
                     "params": {"period": 12}, "cross_indicator": "ema",
                     "cross_params": {"period": 26}, "direction": "crosses_below"}],
    ),
]


@router.get("/templates")
def list_templates():
    return {
        "state": "healthy",
        "reason_codes": [],
        "available_actions": [],
        "templates": CANVAS_TEMPLATES,
    }


# ── Compile / Draft / Publish ─────────────────────────────────────────

def _validation_payload(report) -> dict:
    return {
        "valid": report.valid,
        "error_count": report.error_count,
        "warning_count": report.warning_count,
        "errors": [
            {"code": e.code, "path": e.path, "message": e.message, "severity": e.severity}
            for e in report.errors
        ],
        "warnings": [
            {"code": e.code, "path": e.path, "message": e.message, "severity": e.severity}
            for e in report.warnings
        ],
    }


@router.post("/compile")
def compile_canvas(req: CanvasCompileRequest):
    """Validate a compiled DSL produced by the canvas frontend.

    Returns the authoritative validation report plus the DSL hash that a
    subsequent publish must match (v2.5 hash-pinning invariant).
    """
    report = _validator.validate(req.dsl)
    dsl_hash = compute_dsl_hash(req.dsl)
    return {
        "state": "healthy" if report.valid else "blocked",
        "reason_codes": [] if report.valid else ["dsl_validation_failed"],
        "available_actions": [],
        "dsl_hash": dsl_hash,
        "validation": _validation_payload(report),
    }


@router.post("/save-draft")
def save_draft(req: CanvasDraftRequest, db: Session = Depends(get_db)):
    """Upsert the canvas draft (graph + last compiled DSL) for a strategy."""
    repo = StrategyRepository(db)
    if not repo.get_strategy_by_id(req.strategy_id):
        raise HTTPException(status_code=404, detail="Strategy not found")

    dsl_hash = compute_dsl_hash(req.dsl) if req.dsl else None

    draft = db.query(CanvasDraft).filter(
        CanvasDraft.strategy_id == req.strategy_id
    ).first()
    if draft is None:
        draft = CanvasDraft(
            strategy_id=req.strategy_id,
            graph=req.graph,
            dsl=req.dsl,
            dsl_hash=dsl_hash,
            updated_by=req.updated_by,
        )
        db.add(draft)
    else:
        draft.graph = req.graph
        draft.dsl = req.dsl
        draft.dsl_hash = dsl_hash
        draft.updated_by = req.updated_by
    db.commit()
    db.refresh(draft)

    return {
        "state": "healthy",
        "reason_codes": [],
        "available_actions": [
            {"type": "publish", "enabled": True, "label": "发布为策略版本草稿"},
        ],
        "draft_id": str(draft.id),
        "strategy_id": str(req.strategy_id),
        "dsl_hash": dsl_hash,
    }


@router.get("/strategies/{strategy_id}")
def load_draft(strategy_id: uuid.UUID, db: Session = Depends(get_db)):
    draft = db.query(CanvasDraft).filter(
        CanvasDraft.strategy_id == strategy_id
    ).first()
    if draft is None:
        return {
            "state": "healthy",
            "reason_codes": ["no_draft"],
            "available_actions": [],
            "draft": None,
        }
    return {
        "state": "healthy",
        "reason_codes": [],
        "available_actions": [],
        "draft": {
            "draft_id": str(draft.id),
            "strategy_id": str(draft.strategy_id),
            "graph": draft.graph,
            "dsl": draft.dsl,
            "dsl_hash": draft.dsl_hash,
            "updated_by": draft.updated_by,
            "updated_at": draft.updated_at.isoformat() if draft.updated_at else None,
        },
    }


@router.post("/publish", status_code=201)
def publish_canvas(
    req: CanvasPublishRequest,
    db: Session = Depends(get_db),
    tenant_raw: str | None = Depends(get_current_tenant_id),
):
    """Publish canvas output: DSL must validate, then a draft StrategyVersion
    is created (draft → validated → backtested → … state machine applies)."""
    repo = StrategyRepository(db)
    try:
        tenant_id = int(tenant_raw) if tenant_raw is not None else None
    except (TypeError, ValueError):
        tenant_id = None
    strategy = repo.get_strategy_by_id(req.strategy_id, tenant_id)
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")

    report = _validator.validate(req.dsl)
    if not report.valid:
        raise HTTPException(status_code=422, detail={
            "state": "blocked",
            "reason_codes": ["dsl_validation_failed"],
            "validation": _validation_payload(report),
        })

    dsl_hash = compute_dsl_hash(req.dsl)
    version_no = repo.next_version_no(req.strategy_id)
    version = StrategyVersion(
        strategy_id=req.strategy_id,
        version_no=version_no,
        status="draft",
        dsl_version=req.dsl.get("schema_version", "2.5"),
        rule_dsl=req.dsl,
        dsl_hash=dsl_hash,
        created_by=req.created_by,
        tenant_id=strategy.tenant_id,
    )
    repo.create_version(version)

    # Keep the draft in sync with what was published
    draft = db.query(CanvasDraft).filter(
        CanvasDraft.strategy_id == req.strategy_id
    ).first()
    if draft is not None:
        draft.dsl = req.dsl
        draft.dsl_hash = dsl_hash
        draft.graph = req.graph

    db.commit()
    db.refresh(version)

    return {
        "state": "healthy",
        "reason_codes": [],
        "available_actions": [
            {"type": "validate_version", "enabled": True, "label": "校验策略版本"},
            {"type": "run_backtest", "enabled": True, "label": "运行回测"},
        ],
        "strategy_version_id": str(version.id),
        "version_no": version.version_no,
        "status": version.status,
        "dsl_hash": dsl_hash,
    }
