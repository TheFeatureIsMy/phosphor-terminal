"""Manual tenant subscription (platform admin writes, owner/admin reads)."""
from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.tenant import Membership, Tenant
from app.security.deps import get_current_tenant_id, get_optional_user, require_superuser
from app.services.subscriptions import get_subscription, set_subscription

router = APIRouter(prefix="/api/admin/tenant-subscription", tags=["admin"])


class SubscriptionUpdate(BaseModel):
    plan: str
    status: str = "active"
    current_period_end: datetime | None = None
    provider: str = "manual"
    external_id: str | None = None


def _tenant_id(raw: str | None) -> int:
    try:
        value = int(raw) if raw is not None else None
    except (TypeError, ValueError):
        value = None
    if value is None:
        raise HTTPException(status_code=400, detail="Tenant context required")
    return value


@router.get("")
def read_subscription(
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
    row = get_subscription(db, tenant_id)
    tenant = db.get(Tenant, tenant_id)
    return {
        "plan": tenant.plan if tenant else "free",
        "status": row.status if row else "none",
        "provider": row.provider if row else None,
        "current_period_end": row.current_period_end if row else None,
    }


@router.post("/cancel")
def cancel_subscription(
    tenant_raw: str | None = Depends(get_current_tenant_id),
    admin=Depends(require_superuser),
    db: Session = Depends(get_db),
):
    tenant_id = _tenant_id(tenant_raw)
    tenant = db.get(Tenant, tenant_id)
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    row = get_subscription(db, tenant_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Subscription not found")
    set_subscription(
        db, tenant, plan=row.plan, status="canceled",
        period_end=row.current_period_end, provider=row.provider,
        external_id=row.external_id, actor_user_id=admin.id if admin else None,
    )
    db.commit()
    row = get_subscription(db, tenant_id)
    return {"plan": tenant.plan, "status": row.status, "period_end": row.current_period_end}


@router.put("")
def update_subscription(
    body: SubscriptionUpdate,
    tenant_raw: str | None = Depends(get_current_tenant_id),
    admin=Depends(require_superuser),
    db: Session = Depends(get_db),
):
    if body.plan not in ("free", "pro", "enterprise"):
        raise HTTPException(status_code=422, detail="Unknown plan")
    tenant_id = _tenant_id(tenant_raw)
    tenant = db.get(Tenant, tenant_id)
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    set_subscription(
        db, tenant, plan=body.plan, status=body.status,
        period_end=body.current_period_end, provider=body.provider,
        external_id=body.external_id, actor_user_id=admin.id if admin else None,
    )
    db.commit()
    row = get_subscription(db, tenant_id)
    return {
        "plan": tenant.plan, "status": row.status,
        "current_period_end": row.current_period_end,
    }
