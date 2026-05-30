from __future__ import annotations
import asyncio
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.strategy import NotificationRecord
from app.routers.websocket import manager as ws_manager
from app.services.telegram_notifier import send_telegram_notification

router = APIRouter(prefix="/notifications", tags=["notifications"])


class TelegramDryRunRequest(BaseModel):
    event_type: str = "risk_event"
    severity: str = "medium"
    description: str
    action_taken: str = "review_required"
    chat_id: Optional[str] = None


@router.get("")
def get_notifications(db: Session = Depends(get_db)):
    rows = db.query(NotificationRecord).order_by(NotificationRecord.created_at.desc()).limit(50).all()
    notifications = [
        {
            "id": r.id,
            "type": r.type,
            "title": r.title,
            "message": r.message,
            "read": bool(r.is_read),
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]
    return {"notifications": notifications, "unread": sum(1 for n in notifications if not n["read"])}


@router.put("/{notification_id}/read")
def mark_read(notification_id: int, db: Session = Depends(get_db)):
    row = db.query(NotificationRecord).filter(NotificationRecord.id == notification_id).first()
    if not row:
        return {"ok": False, "detail": "Not found"}
    row.is_read = 1
    db.commit()
    return {"ok": True}


@router.put("/read-all")
def mark_all_read(db: Session = Depends(get_db)):
    db.query(NotificationRecord).update({NotificationRecord.is_read: 1})
    db.commit()
    return {"ok": True}


class NotificationCreateRequest(BaseModel):
    type: str = "info"
    title: str
    message: str


@router.post("", status_code=201)
def create_notification(body: NotificationCreateRequest, db: Session = Depends(get_db)):
    row = NotificationRecord(type=body.type, title=body.title, message=body.message)
    db.add(row)
    db.commit()
    db.refresh(row)
    try:
        asyncio.create_task(ws_manager.broadcast("notifications", {
            "type": "new_notification",
            "notification_id": row.id,
            "title": row.title,
        }))
    except Exception:
        pass
    return {
        "id": row.id,
        "type": row.type,
        "title": row.title,
        "message": row.message,
        "read": False,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


@router.post("/telegram/dry-run")
def telegram_dry_run(body: TelegramDryRunRequest):
    return send_telegram_notification(body.model_dump(), dry_run=True, chat_id=body.chat_id)
