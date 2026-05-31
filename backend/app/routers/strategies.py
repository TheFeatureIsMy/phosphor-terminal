import asyncio
import math
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.models.strategy import Strategy
from app.routers.websocket import manager as ws_manager
from app.schemas.api import (
    StrategyCreate, StrategyUpdate, StrategyResponse,
    StrategyStatus, PaginatedResponse,
    StrategyGenerateRequest, StrategyGenerateResponse,
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
    if strategy.status == "active":
        try:
            asyncio.create_task(ws_manager.broadcast("dashboard", {
                "type": "strategy_deployed",
                "strategy_id": strategy_id,
                "status": "active",
            }))
        except Exception:
            pass
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


@router.post("/{strategy_id}/canvas", status_code=201)
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


# ---------------------------------------------------------------------------
# AI Strategy Generation
# ---------------------------------------------------------------------------


@router.post("/generate", response_model=StrategyGenerateResponse)
def generate_strategy(body: StrategyGenerateRequest, db: Session = Depends(get_db)):
    """Generate a strategy from natural language prompt using AI."""
    from app.models.strategy import CanvasWorkflow
    from app.models.strategy import Strategy

    # Parse trading intent from prompt using LLM
    # For now, extract basic info from prompt keywords
    prompt_lower = body.prompt.lower()

    # Infer market
    if any(k in prompt_lower for k in ["a股", "a股市场", "中国"]):
        market = "ashare"
    elif any(k in prompt_lower for k in ["美股", "美国", "nasdaq", "nyse", "sp500"]):
        market = "usstock"
    else:
        market = "crypto"

    # Infer exchange
    exchange_map = {"binance": "binance", "okx": "okx", "bybit": "bybit", "gate": "gate",
                    "alpaca": "alpaca", "ibkr": "ibkr", "joinquant": "joinquant", "eastmoney": "eastmoney"}
    exchange = "binance"
    for key, val in exchange_map.items():
        if key in prompt_lower:
            exchange = val
            break

    # Infer a name
    name_parts = []
    if "btc" in prompt_lower or "比特币" in prompt_lower:
        name_parts.append("BTC")
    if "eth" in prompt_lower or "以太" in prompt_lower:
        name_parts.append("ETH")
    if "趋势" in prompt_lower or "ema" in prompt_lower or "ma" in prompt_lower:
        name_parts.append("趋势跟踪")
    if "回归" in prompt_lower or "boll" in prompt_lower:
        name_parts.append("均值回归")
    if "突破" in prompt_lower:
        name_parts.append("突破")
    if "网格" in prompt_lower:
        name_parts.append("网格")

    strategy_name = " ".join(name_parts) if name_parts else "AI 生成策略"

    # Build a basic graph based on prompt keywords
    nodes = []
    node_id_counter = 0

    # Data source node
    nodes.append({
        "id": f"node-{node_id_counter}",
        "nodeType": "data.kline",
        "position": {"x": 100, "y": 200},
        "size": {"width": 200, "height": 120},
        "config": {},
        "widgetValues": {},
        "isCollapsed": False,
        "isDisabled": False
    })
    kline_id = node_id_counter
    node_id_counter += 1

    edges = []

    # Add indicator nodes based on prompt keywords
    indicator_y = 100
    prev_indicator_ids = []

    if "rsi" in prompt_lower:
        nodes.append({
            "id": f"node-{node_id_counter}",
            "nodeType": "indicator.rsi",
            "position": {"x": 360, "y": indicator_y},
            "size": {"width": 200, "height": 120},
            "config": {"period": {"value": 14}},
            "widgetValues": {},
            "isCollapsed": False,
            "isDisabled": False
        })
        edges.append({
            "id": f"edge-{node_id_counter}",
            "sourceNodeId": f"node-{kline_id}",
            "sourcePort": "close",
            "targetNodeId": f"node-{node_id_counter}",
            "targetPort": "kline",
            "dataType": "kline"
        })
        prev_indicator_ids.append(node_id_counter)
        indicator_y += 140
        node_id_counter += 1

    if "macd" in prompt_lower:
        nodes.append({
            "id": f"node-{node_id_counter}",
            "nodeType": "indicator.macd",
            "position": {"x": 360, "y": indicator_y},
            "size": {"width": 200, "height": 120},
            "config": {},
            "widgetValues": {},
            "isCollapsed": False,
            "isDisabled": False
        })
        edges.append({
            "id": f"edge-{node_id_counter}",
            "sourceNodeId": f"node-{kline_id}",
            "sourcePort": "close",
            "targetNodeId": f"node-{node_id_counter}",
            "targetPort": "kline",
            "dataType": "kline"
        })
        prev_indicator_ids.append(node_id_counter)
        indicator_y += 140
        node_id_counter += 1

    if "ema" in prompt_lower or "ma" in prompt_lower or "均线" in prompt_lower:
        nodes.append({
            "id": f"node-{node_id_counter}",
            "nodeType": "indicator.ema",
            "position": {"x": 360, "y": indicator_y},
            "size": {"width": 200, "height": 120},
            "config": {},
            "widgetValues": {},
            "isCollapsed": False,
            "isDisabled": False
        })
        edges.append({
            "id": f"edge-{node_id_counter}",
            "sourceNodeId": f"node-{kline_id}",
            "sourcePort": "close",
            "targetNodeId": f"node-{node_id_counter}",
            "targetPort": "kline",
            "dataType": "kline"
        })
        prev_indicator_ids.append(node_id_counter)
        indicator_y += 140
        node_id_counter += 1

    # Decision + output nodes
    if prev_indicator_ids:
        # Add AND decision node
        first_indicator = prev_indicator_ids[0]
        nodes.append({
            "id": f"node-{node_id_counter}",
            "nodeType": "decision.and",
            "position": {"x": 620, "y": 200},
            "size": {"width": 180, "height": 100},
            "config": {},
            "widgetValues": {},
            "isCollapsed": False,
            "isDisabled": False
        })
        decision_id = node_id_counter
        node_id_counter += 1

        # Connect first indicator to decision
        edges.append({
            "id": f"edge-decision-{node_id_counter}",
            "sourceNodeId": f"node-{first_indicator}",
            "sourcePort": "rsiValue" if "rsi" in prompt_lower else "signal",
            "targetNodeId": f"node-{decision_id}",
            "targetPort": "signal",
            "dataType": "signal"
        })

        # Add output node
        nodes.append({
            "id": f"node-{node_id_counter}",
            "nodeType": "output.buy",
            "position": {"x": 860, "y": 200},
            "size": {"width": 180, "height": 80},
            "config": {},
            "widgetValues": {},
            "isCollapsed": False,
            "isDisabled": False
        })
        edges.append({
            "id": f"edge-output-{node_id_counter}",
            "sourceNodeId": f"node-{decision_id}",
            "sourcePort": "result",
            "targetNodeId": f"node-{node_id_counter}",
            "targetPort": "signal",
            "dataType": "boolean"
        })

    import json
    graph_json = json.dumps({
        "nodes": nodes,
        "edges": edges,
        "groups": [],
        "viewport": {"scale": 1.0, "offset": {"x": 0, "y": 0}}
    })

    # Create strategy
    strategy = Strategy(
        name=strategy_name,
        type="ma_cross",
        market=market,
        exchange=exchange,
        parameters={},
        status=StrategyStatus.draft.value,
    )
    db.add(strategy)
    db.commit()
    db.refresh(strategy)

    # Save canvas
    canvas = CanvasWorkflow(
        strategy_id=strategy.id,
        graph_json=graph_json,
        code_snapshot=None,
    )
    db.add(canvas)
    db.commit()

    return StrategyGenerateResponse(
        strategy_id=strategy.id,
        name=strategy.name,
        market=strategy.market,
        exchange=strategy.exchange,
        graph_json=graph_json,
    )
