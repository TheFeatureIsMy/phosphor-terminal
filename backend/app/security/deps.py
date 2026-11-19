"""Authorization dependencies layered on top of AuthMiddleware."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.user import User
from app.services.auth import decode_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


def get_current_tenant_id(request: Request) -> str | None:
    """Tenant id from AuthMiddleware, falling back to the Bearer token.

    Some routers under /auth are public at the middleware layer but still accept
    an optional token (e.g. /auth/members); decode the token there.
    """
    tenant_id = getattr(request.state, "tenant_id", None)
    if tenant_id:
        return tenant_id
    header = request.headers.get("authorization", "")
    if header.lower().startswith("bearer "):
        payload = decode_token(header[7:].strip())
        if payload and payload.get("type") == "access":
            return payload.get("tid")
    return None


def get_optional_user(
    token: str | None = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User | None:
    if not token:
        return None
    payload = decode_token(token)
    if not payload or payload.get("type") != "access" or "sub" not in payload:
        return None
    try:
        user_id = int(payload["sub"])
    except (TypeError, ValueError):
        return None
    sid = payload.get("sid")
    if sid:
        from app.models.tenant import DeviceSession
        session = db.get(DeviceSession, sid)
        now_naive = datetime.now(timezone.utc).replace(tzinfo=None)
        if (
            session is None
            or session.revoked_at is not None
            or (session.expires_at is not None and session.expires_at < now_naive)
        ):
            return None
    return db.get(User, user_id)


def require_superuser(user: User | None = Depends(get_optional_user)) -> User | None:
    """Protect instance-level configuration.

    Tests and local runs with AUTH_REQUIRED=false skip the check; with auth on,
    only the bootstrap/admin account may change provider credentials, system
    settings, or risk policy.
    """
    if not settings.auth_required:
        return None
    if user is None or not user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Superuser privileges required",
        )
    return user


def require_platform_admin(user: User | None = Depends(get_optional_user)) -> User | None:
    """Global Freqtrade-derived data is not tenant-scoped yet.

    Until execution isolation lands, only the bootstrap/platform admin may read
    or control the shared Freqtrade runtime.
    """
    if not settings.auth_required:
        return None
    if user is None or not user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Execution isolation pending; platform admin required",
        )
    return user
