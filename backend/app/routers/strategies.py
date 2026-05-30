import math
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.models.strategy import Strategy
from app.schemas.api import (
    StrategyCreate, StrategyUpdate, StrategyResponse,
    StrategyStatus, PaginatedResponse,
)
from app.services.strategy_registry import register_strategy_file, delete_strategy_file
from app.services.market_registry import market_registry
from app.services.freqtrade_client import freqtrade_client
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
    strategy.freqtrade_strategy_id = register_strategy_file(
        strategy.id,
        strategy.name,
        strategy.type,
        strategy.parameters or {},
    )
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
    strategy.freqtrade_strategy_id = register_strategy_file(
        strategy.id,
        strategy.name,
        strategy.type,
        strategy.parameters or {},
    )
    db.commit()
    db.refresh(strategy)
    return strategy
@router.delete("/{strategy_id}", status_code=204)
def delete_strategy(strategy_id: int, db: Session = Depends(get_db)):
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    if strategy.freqtrade_strategy_id:
        delete_strategy_file(strategy.freqtrade_strategy_id)
    db.delete(strategy)
    db.commit()


@router.post("/{strategy_id}/deploy", response_model=StrategyResponse)
async def deploy_strategy(strategy_id: int, db: Session = Depends(get_db)):
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    if strategy.status == "active":
        raise HTTPException(status_code=400, detail="Strategy is already active")

    if not strategy.freqtrade_strategy_id:
        strategy.freqtrade_strategy_id = register_strategy_file(
            strategy.id,
            strategy.name,
            strategy.type,
            strategy.parameters or {},
        )

    result = await freqtrade_client.start_bot()
    if freqtrade_client.is_success(result):
        strategy.status = "active"
    else:
        strategy.status = "error"
    strategy.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(strategy)
    return strategy


@router.post("/{strategy_id}/stop", response_model=StrategyResponse)
async def stop_strategy(strategy_id: int, db: Session = Depends(get_db)):
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    if strategy.status != "active":
        raise HTTPException(status_code=400, detail="Strategy is not active")

    if strategy.freqtrade_strategy_id:
        await freqtrade_client.stop_bot()
    strategy.status = "paused"
    strategy.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(strategy)
    return strategy


# ---------------------------------------------------------------------------
# Canvas Workflow CRUD
# ---------------------------------------------------------------------------

class CanvasSaveRequest(BaseModel):
    graph_json: str
    code_snapshot: Optional[str] = None


@router.post("/{strategy_id}/canvas")
def save_canvas(strategy_id: int, body: CanvasSaveRequest, db: Session = Depends(get_db)):
    from app.models.strategy import CanvasWorkflow
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")

    existing = db.query(CanvasWorkflow).filter(CanvasWorkflow.strategy_id == strategy_id).first()
    if existing:
        existing.graph_json = body.graph_json
        existing.code_snapshot = body.code_snapshot or existing.code_snapshot
        existing.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(existing)
        return {"id": existing.id, "strategy_id": strategy_id, "updated_at": existing.updated_at.isoformat()}

    workflow = CanvasWorkflow(
        strategy_id=strategy_id,
        graph_json=body.graph_json,
        code_snapshot=body.code_snapshot,
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
        "code_snapshot": workflow.code_snapshot,
        "updated_at": workflow.updated_at.isoformat() if workflow.updated_at else None,
    }


@router.put("/{strategy_id}/canvas")
def update_canvas(strategy_id: int, body: CanvasSaveRequest, db: Session = Depends(get_db)):
    from app.models.strategy import CanvasWorkflow
    workflow = db.query(CanvasWorkflow).filter(CanvasWorkflow.strategy_id == strategy_id).first()
    if not workflow:
        raise HTTPException(status_code=404, detail="Canvas not found for this strategy")
    workflow.graph_json = body.graph_json
    workflow.code_snapshot = body.code_snapshot or workflow.code_snapshot
    workflow.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"id": workflow.id, "strategy_id": strategy_id, "updated_at": workflow.updated_at.isoformat()}
