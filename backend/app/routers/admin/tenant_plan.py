"""Tenant plan management (superuser)."""
from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.tenant import Tenant
from app.models.user import User
from app.security.deps import get_current_tenant_id, get_optional_user
from app.services.tenant_limits import limits_for

router = APIRouter(prefix="/api/admin/tenant-plan", tags=["admin"])

Plan = Literal["free", "pro", "enterprise"]


class PlanUpdate(BaseModel):
    plan: Plan


def _tenant_id(raw: str | None) -> int:
    try:
        value = int(raw) if raw is not None else None
    except (TypeError, ValueError):
        value = None
    if value is None:
        raise HTTPException(status_code=400, detail="Tenant context required")
    return value


@router.get("")
def get_plan(
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
):
    tenant = db.get(Tenant, _tenant_id(tenant_raw))
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return {"tenant_id": tenant.id, "plan": tenant.plan, "limits": limits_for(tenant.plan)}


@router.put("")
def update_plan(
    body: PlanUpdate,
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
    user=Depends(get_optional_user),
):
    tenant = db.get(Tenant, _tenant_id(tenant_raw))
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    tenant.plan = body.plan
    from app.services.tenant_audit import record_tenant_audit

    actor_id = user.id if user and db.get(User, user.id) else None
    record_tenant_audit(
        db, tenant.id, "plan.update",
        actor_user_id=actor_id, detail={"plan": body.plan},
    )
    db.commit()
    return {"tenant_id": tenant.id, "plan": tenant.plan, "limits": limits_for(tenant.plan)}
