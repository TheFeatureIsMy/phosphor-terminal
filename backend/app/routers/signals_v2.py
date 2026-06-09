"""Signal Center v2 API — create, list, detail, lifecycle, conflict, aggregate."""
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.signal_service import SignalService
from app.schemas.signal_v2 import (
    SignalCreate, SignalSummary, SignalView, SignalTransitionRequest,
    SignalConflictCheckRequest, SignalConflictCheckResponse,
    SignalAggregateRequest, SignalAggregateResponse,
)

router = APIRouter(prefix="/api/v2/signals", tags=["signals-v2"])


@router.post("", status_code=201, response_model=SignalSummary)
def create_signal(body: SignalCreate, db: Session = Depends(get_db)):
    svc = SignalService(db)
    signal = svc.create_signal(body.model_dump())
    db.commit()
    return signal


@router.get("", response_model=list[SignalSummary])
def list_signals(
    source_type: str | None = None,
    symbol: str | None = None,
    direction: str | None = None,
    status: str | None = None,
    risk_level: str | None = None,
    days: int = Query(default=7, ge=1, le=90),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    svc = SignalService(db)
    return svc.list_signals(
        source_type=source_type, symbol=symbol, direction=direction,
        status=status, risk_level=risk_level, days=days,
        limit=limit, offset=offset,
    )


@router.get("/{signal_id}", response_model=SignalView)
def get_signal(signal_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = SignalService(db)
    result = svc.get_signal_detail(signal_id)
    if not result:
        raise HTTPException(status_code=404, detail="Signal not found")
    return result


@router.post("/{signal_id}/transition", response_model=SignalSummary)
def transition_signal(signal_id: uuid.UUID, body: SignalTransitionRequest, db: Session = Depends(get_db)):
    svc = SignalService(db)
    try:
        signal = svc.transition_status(signal_id, body.target_status, body.reason)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    db.commit()
    return signal


@router.post("/{signal_id}/archive", response_model=SignalSummary)
def archive_signal(signal_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = SignalService(db)
    try:
        signal = svc.archive_signal(signal_id)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    db.commit()
    return signal


@router.post("/{signal_id}/publish-to-strategy", status_code=201)
def publish_to_strategy(signal_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = SignalService(db)
    try:
        result = svc.publish_to_strategy(signal_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    db.commit()
    return result


@router.post("/{signal_id}/observe-paper", response_model=SignalSummary)
def observe_paper(signal_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = SignalService(db)
    try:
        signal = svc.observe_paper(signal_id)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    db.commit()
    return signal


@router.post("/conflict-check", response_model=SignalConflictCheckResponse)
def conflict_check(body: SignalConflictCheckRequest, db: Session = Depends(get_db)):
    svc = SignalService(db)
    result = svc.conflict_check(body.symbol, body.direction)
    return result


@router.post("/aggregate", response_model=SignalAggregateResponse)
def aggregate_signals(body: SignalAggregateRequest, db: Session = Depends(get_db)):
    svc = SignalService(db)
    result = svc.aggregate(symbols=body.symbols, group_by=body.group_by)
    return result


@router.get("/{signal_id}/next-actions")
def get_signal_next_actions(signal_id: uuid.UUID, db: Session = Depends(get_db)):
    """Return available next actions for a signal based on its current status."""
    svc = SignalService(db)
    detail = svc.get_signal_detail(signal_id)
    if not detail:
        raise HTTPException(status_code=404, detail="Signal not found")

    status = detail.get("status", "") if isinstance(detail, dict) else getattr(detail, "status", "")

    actions = []
    if status == "pending":
        actions = [
            {"type": "transition_active", "enabled": True, "label": "激活"},
            {"type": "reject", "enabled": True, "label": "拒绝"},
        ]
    elif status == "active":
        actions = [
            {"type": "create_strategy_draft", "enabled": True, "label": "生成策略草稿"},
            {"type": "observe_in_dryrun", "enabled": True, "label": "加入 dry-run 观察"},
            {"type": "publish_to_strategy", "enabled": True, "label": "发布到策略"},
            {"type": "reject", "enabled": True, "label": "拒绝"},
        ]
    elif status in ("used_in_strategy", "executed"):
        actions = [
            {"type": "archive", "enabled": True, "label": "归档"},
        ]

    return {"signal_id": str(signal_id), "status": status, "next_actions": actions}
