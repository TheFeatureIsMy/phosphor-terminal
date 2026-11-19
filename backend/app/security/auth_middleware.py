"""Authentication middleware for the AlphaLoop API.

Every HTTP route requires a valid access token unless it is explicitly
allowlisted. WebSocket routes are not covered yet (tracked as P0 debt); they
should be migrated to a query-token handshake before remote deployment.
"""
from __future__ import annotations

from datetime import datetime, timezone

from starlette.responses import JSONResponse

from app.config import settings
from app.security.tenant_context import reset_current_tenant, set_current_tenant
from app.services.auth import decode_token

# Paths that must stay reachable without a token:
# - health probes
# - generated API docs
# - the auth endpoints themselves (login/register/refresh)
PUBLIC_PATHS = {
    "/health",
    "/api/health",
    "/readiness",
    "/api/readiness",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/favicon.ico",
}
PUBLIC_PREFIXES = ("/auth/", "/api/v1/billing/")

_UNAUTHORIZED_BODY = {
    "detail": "Not authenticated",
    "reason_codes": ["authentication_required"],
}


def is_public_path(path: str) -> bool:
    return path in PUBLIC_PATHS or path.startswith(PUBLIC_PREFIXES)


def _extract_bearer(scope) -> str:
    for key, value in scope.get("headers") or []:
        if key == b"authorization":
            raw = value.decode("latin-1").strip()
            if raw.lower().startswith("bearer "):
                return raw[7:].strip()
            return ""
    return ""


class AuthMiddleware:
    """Pure ASGI middleware so request bodies stay untouched."""

    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send) -> None:
        # WebSocket handshakes are skipped until a token handshake lands.
        if scope["type"] != "http" or not settings.auth_required:
            await self.app(scope, receive, send)
            return

        if scope.get("method") == "OPTIONS" or is_public_path(scope.get("path", "")):
            await self.app(scope, receive, send)
            return

        token = _extract_bearer(scope)
        payload = decode_token(token) if token else None
        if not payload or payload.get("type") != "access" or "sub" not in payload:
            response = JSONResponse(
                _UNAUTHORIZED_BODY,
                status_code=401,
                headers={"WWW-Authenticate": "Bearer"},
            )
            await response(scope, receive, send)
            return

        sid = payload.get("sid")
        if sid:
            from app.database import SessionLocal
            from app.models.tenant import DeviceSession

            session_db = SessionLocal()
            try:
                session = session_db.get(DeviceSession, sid)
                now_naive = datetime.now(timezone.utc).replace(tzinfo=None)
                revoked = (
                    session is None
                    or session.revoked_at is not None
                    or (session.expires_at is not None and session.expires_at < now_naive)
                )
            finally:
                session_db.close()
            if revoked:
                response = JSONResponse(
                    {"detail": "Session revoked"},
                    status_code=401,
                    headers={"WWW-Authenticate": "Bearer"},
                )
                await response(scope, receive, send)
                return

        state = scope.setdefault("state", {})
        state["user_id"] = payload["sub"]
        tenant_id = None
        if payload.get("tid"):
            state["tenant_id"] = payload["tid"]
            try:
                tenant_id = int(payload["tid"])
            except (TypeError, ValueError):
                tenant_id = None
        context_token = set_current_tenant(tenant_id)
        try:
            await self.app(scope, receive, send)
        finally:
            reset_current_tenant(context_token)
