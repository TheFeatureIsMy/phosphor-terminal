"""Trade Intent API — submit, query, and confirm trade intents."""
from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.trade_intent_service import TradeIntentService

router = APIRouter(prefix="/api/v2/trade-intents", tags=["trade-intents"])


class TradeIntentCreate(BaseModel):
    strategy_run_id: uuid.UUID
    strategy_version_id: uuid.UUID
    symbol: str
    side: str
    requested_position_pct: float
    mode: str
    intent_type: str = "planned"
    reasoning: str | None = None
    feature_snapshot_id: uuid.UUID | None = None
    signal_snapshots: list[dict[str, Any]] | None = None


class TradeIntentResponse(BaseModel):
    id: uuid.UUID
    status: str
    decision: str | None = None
    final_position_pct: float | None = None
    order_id: uuid.UUID | None = None

    model_config = {"from_attributes": True}


@router.post("", response_model=TradeIntentResponse)
def submit_intent(body: TradeIntentCreate, db: Session = Depends(get_db)):
    svc = TradeIntentService(db)
    result = svc.submit_intent(
        strategy_run_id=body.strategy_run_id,
        strategy_version_id=body.strategy_version_id,
        symbol=body.symbol,
        side=body.side,
        requested_position_pct=body.requested_position_pct,
        mode=body.mode,
        intent_type=body.intent_type,
        reasoning=body.reasoning,
        feature_snapshot_id=body.feature_snapshot_id,
        signal_snapshots=body.signal_snapshots,
    )
    db.commit()
    return TradeIntentResponse(
        id=result.intent.id,
        status=result.intent.status,
        decision=result.decision.decision if result.decision else None,
        final_position_pct=float(result.decision.final_position_pct) if result.decision and result.decision.final_position_pct else None,
        order_id=result.order.id if result.order else None,
    )


@router.get("/{intent_id}", response_model=TradeIntentResponse)
def get_intent(intent_id: uuid.UUID, db: Session = Depends(get_db)):
    from app.domain.trade_intent import TradeIntent, RiskDecision
    from sqlalchemy import select

    intent = db.get(TradeIntent, intent_id)
    if not intent:
        raise HTTPException(status_code=404, detail="Trade intent not found")

    decision = db.scalars(
        select(RiskDecision).where(RiskDecision.trade_intent_id == intent_id)
    ).first()

    return TradeIntentResponse(
        id=intent.id,
        status=intent.status,
        decision=decision.decision if decision else None,
        final_position_pct=float(decision.final_position_pct) if decision and decision.final_position_pct else None,
    )


@router.post("/{intent_id}/confirm", response_model=TradeIntentResponse)
def confirm_intent(intent_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = TradeIntentService(db)
    result = svc.confirm_intent(intent_id)
    if not result:
        raise HTTPException(status_code=400, detail="Intent not in confirmable state")
    db.commit()
    return TradeIntentResponse(
        id=result.intent.id,
        status=result.intent.status,
        decision=result.decision.decision if result.decision else None,
        final_position_pct=float(result.decision.final_position_pct) if result.decision and result.decision.final_position_pct else None,
        order_id=result.order.id if result.order else None,
    )
