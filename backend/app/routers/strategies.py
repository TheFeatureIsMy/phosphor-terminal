import math
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.strategy import Strategy
from app.schemas.api import (
    StrategyCreate, StrategyUpdate, StrategyResponse,
    StrategyStatus, PaginatedResponse,
)
from app.services.market_registry import market_registry

router = APIRouter(prefix="/api/strategies", tags=["strategies"])


@router.get("", response_model=PaginatedResponse)
def list_strategies(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    status: Optional[StrategyStatus] = None,
    db: Session = Depends(get_db),
):
    query = db.query(Strategy)
    if status:
        query = query.filter(Strategy.status == status.value)
    total = query.count()
    items = query.order_by(Strategy.updated_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    return PaginatedResponse(
        items=[StrategyResponse.model_validate(s) for s in items],
        total=total,
        page=page,
        page_size=page_size,
        pages=math.ceil(total / page_size) if total > 0 else 0,
    )


@router.get("/{strategy_id}", response_model=StrategyResponse)
def get_strategy(strategy_id: int, db: Session = Depends(get_db)):
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    return strategy


@router.post("", response_model=StrategyResponse, status_code=201)
def create_strategy(data: StrategyCreate, db: Session = Depends(get_db)):
    try:
        market_registry.validate(data.market, require_enabled=False)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    strategy = Strategy(
        name=data.name,
        type=data.type.value,
        parameters=data.parameters,
        market=data.market,
        exchange=data.exchange,
    )
    db.add(strategy)
    db.commit()
    db.refresh(strategy)
    return strategy


@router.put("/{strategy_id}", response_model=StrategyResponse)
def update_strategy(strategy_id: int, data: StrategyUpdate, db: Session = Depends(get_db)):
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    updates = data.model_dump(exclude_unset=True)
    if "market" in updates:
        try:
            market_registry.validate(updates["market"], require_enabled=False)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
    for field, value in updates.items():
        setattr(strategy, field, value.value if hasattr(value, 'value') else value)
    strategy.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(strategy)
    return strategy


@router.delete("/{strategy_id}", status_code=204)
def delete_strategy(strategy_id: int, db: Session = Depends(get_db)):
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    db.delete(strategy)
    db.commit()


@router.post("/{strategy_id}/deploy", response_model=StrategyResponse)
async def deploy_strategy(strategy_id: int, db: Session = Depends(get_db)):
    """v2.5: Deploy must go through Command Bus. Not yet implemented."""
    raise HTTPException(
        status_code=501,
        detail="v2.5: Strategy deployment requires Command Bus (Phase 02). Not yet implemented.",
    )


@router.post("/{strategy_id}/stop", response_model=StrategyResponse)
async def stop_strategy(strategy_id: int, db: Session = Depends(get_db)):
    """v2.5: Stop must go through Command Bus. Not yet implemented."""
    raise HTTPException(
        status_code=501,
        detail="v2.5: Strategy stop requires Command Bus (Phase 02). Not yet implemented.",
    )


# ---------------------------------------------------------------------------
# Canvas Workflow CRUD (v2.5: graph_json only, no code_snapshot)
# ---------------------------------------------------------------------------

class CanvasSaveRequest(BaseModel):
    graph_json: str


@router.post("/{strategy_id}/canvas", status_code=201)
def save_canvas(strategy_id: int, body: CanvasSaveRequest, db: Session = Depends(get_db)):
    from app.models.strategy import CanvasWorkflow
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")

    existing = db.query(CanvasWorkflow).filter(CanvasWorkflow.strategy_id == strategy_id).first()
    if existing:
        existing.graph_json = body.graph_json
        existing.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(existing)
        return {"id": existing.id, "strategy_id": strategy_id, "updated_at": existing.updated_at.isoformat()}

    workflow = CanvasWorkflow(
        strategy_id=strategy_id,
        graph_json=body.graph_json,
    )
    db.add(workflow)
    db.commit()
    db.refresh(workflow)
    return {"id": workflow.id, "strategy_id": strategy_id, "created_at": workflow.created_at.isoformat()}


@router.get("/{strategy_id}/canvas")
def load_canvas(strategy_id: int, db: Session = Depends(get_db)):
    from app.models.strategy import CanvasWorkflow
    workflow = db.query(CanvasWorkflow).filter(CanvasWorkflow.strategy_id == strategy_id).first()
    if not workflow:
        raise HTTPException(status_code=404, detail="Canvas not found for this strategy")
    return {
        "id": workflow.id,
        "strategy_id": strategy_id,
        "graph_json": workflow.graph_json,
        "updated_at": workflow.updated_at.isoformat() if workflow.updated_at else None,
    }


@router.put("/{strategy_id}/canvas")
def update_canvas(strategy_id: int, body: CanvasSaveRequest, db: Session = Depends(get_db)):
    from app.models.strategy import CanvasWorkflow
    workflow = db.query(CanvasWorkflow).filter(CanvasWorkflow.strategy_id == strategy_id).first()
    if not workflow:
        raise HTTPException(status_code=404, detail="Canvas not found for this strategy")
    workflow.graph_json = body.graph_json
    workflow.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"id": workflow.id, "strategy_id": strategy_id, "updated_at": workflow.updated_at.isoformat()}
