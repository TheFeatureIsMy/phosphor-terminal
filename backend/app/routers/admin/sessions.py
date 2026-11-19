"""Session retention cleanup (admin)."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.tenant import DeviceSession

router = APIRouter(prefix="/api/admin/sessions", tags=["admin"])


@router.post("/cleanup")
def cleanup_sessions(
    retention_days: int = Query(default=30, ge=1, le=3650),
    db: Session = Depends(get_db),
):
    cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=retention_days)
    rows = db.query(DeviceSession).filter(
        or_(
            DeviceSession.revoked_at.isnot(None) & (DeviceSession.revoked_at < cutoff),
            DeviceSession.expires_at.isnot(None) & (DeviceSession.expires_at < cutoff),
        )
    ).all()
    count = len(rows)
    for row in rows:
        db.delete(row)
    db.commit()
    return {"deleted": count, "retention_days": retention_days}
