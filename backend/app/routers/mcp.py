"""MCP (Model Context Protocol) API — status, audit logs, token management."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.mcp import (
    McpAuditLogView,
    McpStatusView,
    McpTokenRotateRequest,
    McpTokenRotateResponse,
)
from app.services.mcp_service import McpService

router = APIRouter(prefix="/api/mcp", tags=["mcp"])


@router.get("/status", response_model=McpStatusView)
def get_mcp_status(db: Session = Depends(get_db)):
    svc = McpService(db)
    return svc.get_status()


@router.get("/audit-logs", response_model=list[McpAuditLogView])
def list_audit_logs(
    tool_name: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    svc = McpService(db)
    return svc.list_audit_logs(limit=limit, offset=offset, tool_name=tool_name)


@router.post("/rotate-token", response_model=McpTokenRotateResponse)
def rotate_token(body: McpTokenRotateRequest, db: Session = Depends(get_db)):
    svc = McpService(db)
    result = svc.rotate_token(reason=body.reason)
    db.commit()
    return result
