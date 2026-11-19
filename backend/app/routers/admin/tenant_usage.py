"""Current tenant usage vs plan limits (owner/admin)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.domain.strategy import StrategyV2
from app.models.tenant import DeviceSession, Membership, Tenant, TenantAuditLog
from app.security.deps import get_current_tenant_id, get_optional_user
from app.services.tenant_limits import limits_for, quota_warnings

router = APIRouter(prefix="/api/admin/tenant-usage", tags=["admin"])


def _tenant_id(raw: str | None) -> int:
    try:
        value = int(raw) if raw is not None else None
    except (TypeError, ValueError):
        value = None
    if value is None:
        raise HTTPException(status_code=400, detail="Tenant context required")
    return value


@router.get("")
def get_usage(
    tenant_raw: str | None = Depends(get_current_tenant_id),
    user=Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    if user is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    tenant_id = _tenant_id(tenant_raw)
    membership = db.scalar(
        select(Membership).where(
            Membership.user_id == user.id, Membership.tenant_id == tenant_id
        )
    )
    if membership is None or membership.role not in ("owner", "admin"):
        raise HTTPException(status_code=403, detail="Tenant manager required")
    tenant = db.get(Tenant, tenant_id)
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    usage = {
            "members": db.scalar(
                select(func.count()).select_from(Membership).where(
                    Membership.tenant_id == tenant_id
                )
            ) or 0,
            "strategies": db.scalar(
                select(func.count()).select_from(StrategyV2).where(
                    StrategyV2.tenant_id == tenant_id
                )
            ) or 0,
            "audit_logs": db.scalar(
                select(func.count()).select_from(TenantAuditLog).where(
                    TenantAuditLog.tenant_id == tenant_id
                )
            ) or 0,
            "active_sessions": db.scalar(
                select(func.count()).select_from(DeviceSession).where(
                    DeviceSession.tenant_id == tenant_id,
                    DeviceSession.revoked_at.is_(None),
                )
            ) or 0,
        }
    return {
        "plan": tenant.plan,
        "limits": limits_for(tenant.plan),
        "usage": usage,
        "warnings": quota_warnings(tenant.plan, usage),
    }
