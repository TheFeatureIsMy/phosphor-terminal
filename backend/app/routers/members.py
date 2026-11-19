"""Tenant membership management (owner/admin only)."""
from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.tenant import Membership, Tenant
from app.models.user import User
from app.routers.auth import get_current_user
from app.security.deps import get_current_tenant_id
from app.services.auth import get_password_hash
from app.services.tenant_limits import enforce_member_limit
from app.services.tenant_audit import record_tenant_audit

router = APIRouter(prefix="/auth/members", tags=["members"])

Role = Literal["owner", "admin", "trader", "viewer"]


class MemberCreate(BaseModel):
    username: str
    email: str
    password: str
    role: Role = "viewer"


class MemberUpdate(BaseModel):
    role: Role


class MemberResponse(BaseModel):
    user_id: int
    username: str
    email: str
    role: str
    is_active: bool


def _tenant_id(raw: str | None) -> int:
    try:
        value = int(raw) if raw is not None else None
    except (TypeError, ValueError):
        value = None
    if value is None:
        raise HTTPException(status_code=400, detail="Tenant context required")
    return value


def _membership(db: Session, tenant_id: int, user_id: int) -> Membership | None:
    return db.query(Membership).filter(
        Membership.tenant_id == tenant_id, Membership.user_id == user_id,
    ).first()


def _require_manager(db: Session, tenant_id: int, user: User) -> None:
    if not settings.auth_required:
        return
    if user.is_superuser:
        return
    membership = _membership(db, tenant_id, user.id)
    if membership is None or membership.role not in ("owner", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tenant owner or admin required",
        )


def _owner_count(db: Session, tenant_id: int) -> int:
    return db.query(Membership).filter(
        Membership.tenant_id == tenant_id, Membership.role == "owner",
    ).count()


def _view(user: User, membership: Membership) -> MemberResponse:
    return MemberResponse(
        user_id=user.id, username=user.username, email=user.email,
        role=membership.role, is_active=user.is_active,
    )


@router.get("", response_model=list[MemberResponse])
def list_members(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    tenant_raw: str | None = Depends(get_current_tenant_id),
):
    tenant_id = _tenant_id(tenant_raw)
    _require_manager(db, tenant_id, user)
    rows = (
        db.query(User, Membership)
        .join(Membership, Membership.user_id == User.id)
        .filter(Membership.tenant_id == tenant_id)
        .order_by(Membership.id.asc())
        .all()
    )
    return [_view(u, m) for u, m in rows]


@router.post("", response_model=MemberResponse, status_code=201)
def add_member(
    body: MemberCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    tenant_raw: str | None = Depends(get_current_tenant_id),
):
    tenant_id = _tenant_id(tenant_raw)
    _require_manager(db, tenant_id, user)
    if db.query(User).filter(
        (User.username == body.username) | (User.email == body.email)
    ).first():
        raise HTTPException(status_code=409, detail="User already exists")
    tenant = db.get(Tenant, tenant_id)
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    current = db.query(Membership).filter(Membership.tenant_id == tenant_id).count()
    enforce_member_limit(db, tenant, current)

    member = User(
        username=body.username, email=body.email,
        hashed_password=get_password_hash(body.password),
        is_active=True, is_superuser=False,
    )
    db.add(member)
    db.flush()
    membership = Membership(
        user_id=member.id, tenant_id=tenant_id, role=body.role,
    )
    db.add(membership)
    record_tenant_audit(
        db, tenant_id, "member.add", actor_user_id=user.id,
        detail={"member_user_id": member.id, "role": body.role},
    )
    db.commit()
    db.refresh(member)
    db.refresh(membership)
    return _view(member, membership)


@router.patch("/{user_id}", response_model=MemberResponse)
def update_member_role(
    user_id: int,
    body: MemberUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    tenant_raw: str | None = Depends(get_current_tenant_id),
):
    tenant_id = _tenant_id(tenant_raw)
    _require_manager(db, tenant_id, user)
    membership = _membership(db, tenant_id, user_id)
    if membership is None:
        raise HTTPException(status_code=404, detail="Membership not found")
    if membership.role == "owner" and body.role != "owner":
        if _owner_count(db, tenant_id) <= 1:
            raise HTTPException(status_code=409, detail="Cannot demote the last owner")
    previous = membership.role
    membership.role = body.role
    record_tenant_audit(
        db, tenant_id, "member.role", actor_user_id=user.id,
        detail={"member_user_id": user_id, "from": previous, "to": body.role},
    )
    db.commit()
    member = db.get(User, user_id)
    return _view(member, membership)


@router.delete("/{user_id}", status_code=204)
def remove_member(
    user_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    tenant_raw: str | None = Depends(get_current_tenant_id),
):
    tenant_id = _tenant_id(tenant_raw)
    _require_manager(db, tenant_id, user)
    membership = _membership(db, tenant_id, user_id)
    if membership is None:
        raise HTTPException(status_code=404, detail="Membership not found")
    if membership.role == "owner" and _owner_count(db, tenant_id) <= 1:
        raise HTTPException(status_code=409, detail="Cannot remove the last owner")
    removed_role = membership.role
    db.delete(membership)
    record_tenant_audit(
        db, tenant_id, "member.remove", actor_user_id=user.id,
        detail={"member_user_id": user_id, "role": removed_role},
    )
    db.commit()
    return None
