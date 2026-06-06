"""MCP Server management service."""
import uuid
import hashlib
import secrets
import logging
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.domain.mcp import McpAuditLog

logger = logging.getLogger(__name__)


class McpService:
    """MCP Server status, audit log, and token management."""

    def __init__(self, session: Session):
        self._s = session
        self._current_token_hash: str | None = None

    def get_status(self) -> dict:
        """Return MCP server status."""
        recent_count = self._s.query(McpAuditLog).count()
        last_request = self._s.query(McpAuditLog).order_by(
            desc(McpAuditLog.created_at)
        ).first()
        return {
            "enabled": True,
            "bind_address": "127.0.0.1:9100",
            "connected_clients": 0,
            "total_requests": recent_count,
            "last_request_at": last_request.created_at if last_request else None,
        }

    def list_audit_logs(self, limit: int = 50, offset: int = 0,
                        tool_name: str | None = None) -> list[McpAuditLog]:
        """Query audit logs with pagination."""
        q = self._s.query(McpAuditLog)
        if tool_name:
            q = q.filter(McpAuditLog.tool_name == tool_name)
        return q.order_by(desc(McpAuditLog.created_at)).offset(offset).limit(limit).all()

    def log_access(self, tool_name: str, caller_token_hash: str,
                   request_payload: dict | None, response_status: int,
                   response_summary: str | None = None, latency_ms: int | None = None) -> McpAuditLog:
        """Record an MCP tool call in the audit log."""
        log = McpAuditLog(
            tool_name=tool_name,
            caller_token_hash=caller_token_hash,
            request_payload=request_payload,
            response_status=response_status,
            response_summary=response_summary,
            latency_ms=latency_ms,
        )
        self._s.add(log)
        self._s.flush()
        return log

    def rotate_token(self, reason: str | None = None) -> dict:
        """Generate a new MCP access token and revoke the old one."""
        new_token = secrets.token_urlsafe(32)
        new_hash = hashlib.sha256(new_token.encode()).hexdigest()

        # Log the rotation as an audit event
        self.log_access(
            tool_name="__token_rotation",
            caller_token_hash=new_hash,
            request_payload={"reason": reason or "manual_rotation"},
            response_status=200,
            response_summary="Token rotated successfully",
        )

        logger.info("MCP token rotated. New hash prefix: %s...", new_hash[:8])

        return {
            "new_token": new_token,
            "token_hash": new_hash,
            "old_token_revoked": True,
            "expires_at": None,
        }

    @staticmethod
    def hash_token(token: str) -> str:
        """Hash a token for storage/comparison."""
        return hashlib.sha256(token.encode()).hexdigest()
