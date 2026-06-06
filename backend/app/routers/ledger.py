"""Execution Ledger API — append-only event recording and querying."""
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.ledger import LedgerEventCreate, LedgerEventResponse, LedgerEventListResponse
from app.services.ledger_service import LedgerService

router = APIRouter(prefix="/api/v2/ledger", tags=["execution-ledger"])


@router.post("/events", response_model=LedgerEventResponse, status_code=201)
def append_event(body: LedgerEventCreate, db: Session = Depends(get_db)):
    svc = LedgerService(db)
    event, created = svc.record_event(
        event_type=body.event_type,
        source_system=body.source_system,
        source_event_id=body.source_event_id,
        normalized_payload=body.normalized_payload,
        raw_payload=body.raw_payload,
        event_time=body.event_time,
        strategy_run_id=body.strategy_run_id,
        freqtrade_run_id=body.freqtrade_run_id,
        command_id=body.command_id,
        trade_intent_id=body.trade_intent_id,
        risk_decision_id=body.risk_decision_id,
        symbol=body.symbol,
        sequence_no=body.sequence_no,
        correlation_id=body.correlation_id,
        causation_id=body.causation_id,
    )
    db.commit()
    db.refresh(event)
    return event


@router.get("/events/{event_id}", response_model=LedgerEventResponse)
def get_event(event_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = LedgerService(db)
    event = svc.get_event(event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")
    return event


@router.get("/events", response_model=LedgerEventListResponse)
def list_events(
    strategy_run_id: Optional[uuid.UUID] = Query(None),
    command_id: Optional[uuid.UUID] = Query(None),
    correlation_id: Optional[uuid.UUID] = Query(None),
    event_type: Optional[str] = Query(None),
    source_system: Optional[str] = Query(None),
    symbol: Optional[str] = Query(None),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    db: Session = Depends(get_db),
):
    svc = LedgerService(db)
    items = svc.list_events(
        strategy_run_id=strategy_run_id,
        command_id=command_id,
        correlation_id=correlation_id,
        event_type=event_type,
        source_system=source_system,
        symbol=symbol,
        offset=offset,
        limit=limit,
    )
    return LedgerEventListResponse(items=items, offset=offset, limit=limit)
