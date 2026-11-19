"""Tenant audit log (owner/admin)."""
from __future__ import annotations

import csv
import io

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse, Response
from pathlib import Path
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.tenant import Membership, TenantAuditLog
from app.security.deps import get_current_tenant_id, get_optional_user, require_superuser

router = APIRouter(prefix="/api/admin/tenant-audit", tags=["admin"])


def _tenant_id(raw: str | None) -> int:
    try:
        value = int(raw) if raw is not None else None
    except (TypeError, ValueError):
        value = None
    if value is None:
        raise HTTPException(status_code=400, detail="Tenant context required")
    return value


@router.get("")
def list_audit(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    action: str | None = Query(None, max_length=80),
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
    stmt = select(TenantAuditLog).where(TenantAuditLog.tenant_id == tenant_id)
    if action:
        stmt = stmt.where(TenantAuditLog.action == action)
    stmt = (
        stmt.order_by(TenantAuditLog.created_at.desc(), TenantAuditLog.id.desc())
        .offset(offset)
        .limit(limit)
    )
    rows = list(db.scalars(stmt).all())
    return [
        {
            "id": row.id,
            "action": row.action,
            "actor_user_id": row.actor_user_id,
            "detail": row.detail or {},
            "created_at": row.created_at.isoformat() if row.created_at else None,
        }
        for row in rows
    ]


@router.get("/export")
def export_audit(
    action: str | None = Query(None, max_length=80),
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
    stmt = select(TenantAuditLog).where(TenantAuditLog.tenant_id == tenant_id)
    if action:
        stmt = stmt.where(TenantAuditLog.action == action)
    rows = db.scalars(
        stmt.order_by(TenantAuditLog.created_at.desc(), TenantAuditLog.id.desc())
    ).all()
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(["id", "created_at", "action", "actor_user_id", "detail"])
    for row in rows:
        writer.writerow([
            row.id,
            row.created_at.isoformat() if row.created_at else "",
            row.action,
            row.actor_user_id or "",
            __import__("json").dumps(row.detail or {}, ensure_ascii=False),
        ])
    return Response(
        content=buffer.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="tenant-{tenant_id}-audit.csv"'
        },
    )


@router.get("/archives")
def list_archives(_admin=Depends(require_superuser)):
    from app.config import settings

    root = Path(settings.tenant_audit_archive_dir).resolve()
    if not settings.tenant_audit_archive_dir or not root.is_dir():
        return []
    return [
        {
            "name": path.name,
            "size": path.stat().st_size,
            "modified_at": path.stat().st_mtime,
        }
        for path in sorted(root.glob("*.jsonl.gz"), reverse=True)
    ]


@router.get("/archives/{name}")
def download_archive(name: str, _admin=Depends(require_superuser)):
    from app.config import settings

    if Path(name).name != name or not name.endswith(".jsonl.gz"):
        raise HTTPException(status_code=400, detail="Invalid archive name")
    root = Path(settings.tenant_audit_archive_dir).resolve()
    path = (root / name).resolve()
    if not settings.tenant_audit_archive_dir or not path.is_relative_to(root) or not path.is_file():
        raise HTTPException(status_code=404, detail="Archive not found")
    return FileResponse(path, media_type="application/gzip", filename=name)
