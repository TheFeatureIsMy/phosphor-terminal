"""Command Bus API — enqueue and query commands."""
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.command import CommandCreate, CommandResponse, CommandCancelResponse
from app.services.command_bus import CommandBusService

router = APIRouter(prefix="/api/v2/commands", tags=["command-bus"])


@router.post("", response_model=CommandResponse, status_code=201)
def enqueue_command(body: CommandCreate, db: Session = Depends(get_db)):
    svc = CommandBusService(db)
    cmd, created = svc.enqueue(
        command_type=body.command_type,
        aggregate_type=body.aggregate_type,
        aggregate_id=body.aggregate_id,
        payload=body.payload,
        idempotency_key=body.idempotency_key,
        requested_by=body.requested_by,
        priority=body.priority,
        max_retries=body.max_retries,
        timeout_sec=body.timeout_sec,
        correlation_id=body.correlation_id,
    )
    db.commit()
    db.refresh(cmd)
    return cmd


@router.get("/{command_id}", response_model=CommandResponse)
def get_command(command_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = CommandBusService(db)
    cmd = svc.get_by_id(command_id)
    if cmd is None:
        raise HTTPException(status_code=404, detail="Command not found")
    return cmd


@router.post("/{command_id}/cancel", response_model=CommandCancelResponse)
def cancel_command(command_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = CommandBusService(db)
    success, reason = svc.cancel(command_id)
    db.commit()
    if not success and reason == "not_found":
        raise HTTPException(status_code=404, detail="Command not found")
    return CommandCancelResponse(success=success, reason=reason)
