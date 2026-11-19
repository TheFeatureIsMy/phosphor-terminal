"""Tenant-scoped audit trail for administrative actions."""
from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.tenant import TenantAuditLog
from app.models.user import User


def actor_id_for(db: Session, user) -> int | None:
    if user is None:
        return None
    return user.id if db.get(User, user.id) else None


def record_tenant_audit(
    db: Session,
    tenant_id: int,
    action: str,
    actor_user_id: int | None = None,
    detail: dict | None = None,
) -> TenantAuditLog:
    entry = TenantAuditLog(
        tenant_id=tenant_id,
        actor_user_id=actor_user_id,
        action=action,
        detail=detail or {},
    )
    db.add(entry)
    return entry
