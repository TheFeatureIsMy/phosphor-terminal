"""Execution runtime routing for tenant users.

Superusers / auth-disabled installs use the platform-shared Freqtrade runtime.
Tenant users need an enabled ``dedicated`` profile with a URL; otherwise the
execution API is closed for that tenant.
"""
from __future__ import annotations

from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.tenant import TenantExecutionProfile
from app.models.user import User
from app.security.deps import get_current_tenant_id, get_optional_user


def get_execution_client(
    tenant_raw: str | None = Depends(get_current_tenant_id),
    user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
) -> FreqtradeClient:
    from app.services.freqtrade_client import FreqtradeClient

    if not settings.auth_required:
        return FreqtradeClient()
    if user is not None and user.is_superuser:
        return FreqtradeClient()

    try:
        tenant_id = int(tenant_raw) if tenant_raw is not None else None
    except (TypeError, ValueError):
        tenant_id = None
    if tenant_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tenant execution is not configured",
        )

    profile = (
        db.query(TenantExecutionProfile)
        .filter(TenantExecutionProfile.tenant_id == tenant_id)
        .first()
    )
    if (
        profile is None
        or not profile.enabled
        or profile.mode != "dedicated"
        or not profile.freqtrade_url
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tenant execution is not configured",
        )
    password = None
    if profile.api_password_ct:
        from app.services.crypto_service import CryptoService
        password = CryptoService().decrypt(
            profile.api_password_ct, tenant_id=tenant_id,
        )
    return FreqtradeClient(
        base_url=profile.freqtrade_url,
        username=profile.api_username,
        password=password,
    )
