from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(prefix="/notifications", tags=["notifications"])


class Notification(BaseModel):
    id: int
    type: str
    title: str
    message: str
    read: bool
    created_at: datetime


# In-memory notifications for now (would be DB-backed in production)
_notifications: list[dict] = [
    {
        "id": 1,
        "type": "trade",
        "title": "策略执行",
        "message": "MA交叉策略在 BTC/USDT 上触发买入信号",
        "read": False,
        "created_at": datetime.now(timezone.utc).isoformat(),
    },
    {
        "id": 2,
        "type": "risk",
        "title": "风控预警",
        "message": "ETH/USDT 持仓回撤达到 8%，接近止损线",
        "read": False,
        "created_at": datetime.now(timezone.utc).isoformat(),
    },
    {
        "id": 3,
        "type": "system",
        "title": "系统状态",
        "message": "Freqtrade 引擎已重新连接",
        "read": True,
        "created_at": datetime.now(timezone.utc).isoformat(),
    },
]


@router.get("")
def get_notifications():
    return {"notifications": _notifications, "unread": sum(1 for n in _notifications if not n["read"])}


@router.put("/{notification_id}/read")
def mark_read(notification_id: int):
    for n in _notifications:
        if n["id"] == notification_id:
            n["read"] = True
            return {"ok": True}
    return {"ok": False, "detail": "Not found"}


@router.put("/read-all")
def mark_all_read():
    for n in _notifications:
        n["read"] = True
    return {"ok": True}
