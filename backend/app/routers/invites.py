"""Tenant invite links (email delivery is optional/out of band)."""
from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.tenant import Membership, Tenant, TenantInvite
from app.models.user import User
from app.routers.auth import get_current_user
from app.routers.members import _require_manager, _tenant_id
from app.security.deps import get_current_tenant_id
from app.services.auth import get_password_hash
from app.services.tenant_limits import enforce_member_limit
from app.services.tenant_audit import record_tenant_audit

router = APIRouter(prefix="/auth/invites", tags=["invites"])

Role = Literal["owner", "admin", "trader", "viewer"]


class InviteCreate(BaseModel):
    email: str
    role: Role = "viewer"


class InviteAccept(BaseModel):
    token: str
    username: str
    password: str


class InviteResponse(BaseModel):
    id: str
    email: str
    role: str
    expires_at: datetime
    accepted: bool


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


@router.post("", status_code=201)
def create_invite(
    body: InviteCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    tenant_raw: str | None = Depends(get_current_tenant_id),
):
    tenant_id = _tenant_id(tenant_raw)
    _require_manager(db, tenant_id, user)
    if db.get(Tenant, tenant_id) is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    token = secrets.token_urlsafe(32)
    invite = TenantInvite(
        id=str(uuid.uuid4()), tenant_id=tenant_id, email=body.email,
        role=body.role, token_hash=_hash(token), created_by=user.id,
        expires_at=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=7),
    )
    db.add(invite)
    record_tenant_audit(
        db, tenant_id, "invite.create", actor_user_id=user.id,
        detail={"email": body.email, "role": body.role},
    )
    db.commit()
    from app.config import settings
    from app.services.email_service import EmailService

    link = f"{settings.public_base_url.rstrip('/')}/?invite_token={token}"
    tenant = db.get(Tenant, tenant_id)
    email_sent = EmailService().send_invite(
        to=invite.email, link=link, tenant_name=tenant.name if tenant else "AlphaLoop",
    )
    return {
        "id": invite.id, "email": invite.email, "role": invite.role,
        "expires_at": invite.expires_at, "token": token,
        "accept_path": "/auth/invites/accept",
        "invite_link": link, "email_sent": email_sent,
    }


@router.get("", response_model=list[InviteResponse])
def list_invites(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    tenant_raw: str | None = Depends(get_current_tenant_id),
):
    tenant_id = _tenant_id(tenant_raw)
    _require_manager(db, tenant_id, user)
    rows = db.query(TenantInvite).filter(
        TenantInvite.tenant_id == tenant_id
    ).order_by(TenantInvite.created_at.desc()).all()
    return [
        InviteResponse(
            id=row.id, email=row.email, role=row.role,
            expires_at=row.expires_at, accepted=row.accepted_at is not None,
        )
        for row in rows
    ]


@router.post("/accept", status_code=201)
def accept_invite(body: InviteAccept, db: Session = Depends(get_db)):
    invite = db.query(TenantInvite).filter(
        TenantInvite.token_hash == _hash(body.token)
    ).first()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if invite is None or invite.accepted_at is not None or invite.expires_at < now:
        raise HTTPException(status_code=400, detail="Invite is invalid or expired")
    if db.query(User).filter(
        (User.username == body.username) | (User.email == invite.email)
    ).first():
        raise HTTPException(status_code=409, detail="User already exists")

    tenant = db.get(Tenant, invite.tenant_id)
    if tenant is None:
        raise HTTPException(status_code=404, detail="Tenant not found")
    current = db.query(Membership).filter(
        Membership.tenant_id == invite.tenant_id
    ).count()
    enforce_member_limit(db, tenant, current)

    user = User(
        username=body.username, email=invite.email,
        hashed_password=get_password_hash(body.password),
        is_active=True, is_superuser=False,
    )
    db.add(user)
    db.flush()
    db.add(Membership(user_id=user.id, tenant_id=invite.tenant_id, role=invite.role))
    invite.accepted_at = now
    record_tenant_audit(
        db, invite.tenant_id, "invite.accept", actor_user_id=user.id,
        detail={"email": invite.email, "role": invite.role},
    )
    db.commit()
    return {"status": "accepted", "user_id": user.id, "tenant_id": invite.tenant_id}
