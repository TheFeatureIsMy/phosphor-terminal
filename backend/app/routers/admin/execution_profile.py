"""Per-tenant execution runtime profile (admin)."""
from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.tenant import TenantExecutionProfile
from app.services.tenant_audit import actor_id_for, record_tenant_audit
from app.security.deps import get_current_tenant_id, get_optional_user

router = APIRouter(prefix="/api/admin/execution-profile", tags=["admin"])


class ExecutionProfileUpdate(BaseModel):
    mode: Literal["disabled", "dedicated"] = "disabled"
    freqtrade_url: str | None = None
    api_username: str | None = None
    api_password: str | None = None
    exchange_key: str | None = None
    exchange_secret: str | None = None
    enabled: bool = False
    max_open_trades: int = 2


def _tenant_id(raw: str | None) -> int:
    try:
        value = int(raw) if raw is not None else None
    except (TypeError, ValueError):
        value = None
    if value is None:
        raise HTTPException(status_code=400, detail="Tenant context required")
    return value


@router.get("")
def get_execution_profile(
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
):
    tenant_id = _tenant_id(tenant_raw)
    row = db.query(TenantExecutionProfile).filter(
        TenantExecutionProfile.tenant_id == tenant_id
    ).first()
    if row is None:
        return {
            "tenant_id": tenant_id, "mode": "disabled", "freqtrade_url": None,
            "api_username": None, "has_credentials": False,
            "has_exchange_credentials": False,
            "enabled": False, "max_open_trades": 2,
            "runtime_status": "unknown", "last_health_at": None, "last_error": None,
        }
    return {
        "tenant_id": row.tenant_id, "mode": row.mode,
        "freqtrade_url": row.freqtrade_url,
        "api_username": row.api_username,
        "has_credentials": bool(row.api_password_ct),
        "has_exchange_credentials": bool(row.exchange_key_ct and row.exchange_secret_ct),
        "enabled": row.enabled,
        "max_open_trades": row.max_open_trades,
        "runtime_status": row.runtime_status,
        "last_health_at": row.last_health_at.isoformat() if row.last_health_at else None,
        "last_error": row.last_error,
    }


@router.put("")
def update_execution_profile(
    body: ExecutionProfileUpdate,
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
    user=Depends(get_optional_user),
):
    tenant_id = _tenant_id(tenant_raw)
    if body.enabled and body.mode == "dedicated" and not body.freqtrade_url:
        raise HTTPException(
            status_code=422, detail="dedicated mode requires freqtrade_url",
        )
    row = db.query(TenantExecutionProfile).filter(
        TenantExecutionProfile.tenant_id == tenant_id
    ).first()
    if row is None:
        row = TenantExecutionProfile(tenant_id=tenant_id)
        db.add(row)
    row.mode = body.mode
    row.freqtrade_url = body.freqtrade_url
    row.enabled = body.enabled
    row.max_open_trades = body.max_open_trades
    fields = body.model_fields_set
    if "api_username" in fields:
        row.api_username = body.api_username
    if "exchange_key" in fields or "exchange_secret" in fields:
        from app.services.crypto_service import CryptoService
        crypto = CryptoService()
        if "exchange_key" in fields:
            row.exchange_key_ct = (
                crypto.encrypt(body.exchange_key, tenant_id=tenant_id)
                if body.exchange_key else None
            )
        if "exchange_secret" in fields:
            row.exchange_secret_ct = (
                crypto.encrypt(body.exchange_secret, tenant_id=tenant_id)
                if body.exchange_secret else None
            )
    if "api_password" in fields:
        if body.api_password:
            from app.services.crypto_service import CryptoService
            row.api_password_ct = CryptoService().encrypt(
                body.api_password, tenant_id=tenant_id,
            )
        else:
            row.api_password_ct = None
    db.commit()
    db.refresh(row)
    return {
        "tenant_id": row.tenant_id, "mode": row.mode,
        "freqtrade_url": row.freqtrade_url,
        "api_username": row.api_username,
        "has_credentials": bool(row.api_password_ct),
        "has_exchange_credentials": bool(row.exchange_key_ct and row.exchange_secret_ct),
        "enabled": row.enabled,
        "max_open_trades": row.max_open_trades,
        "runtime_status": row.runtime_status,
        "last_health_at": row.last_health_at.isoformat() if row.last_health_at else None,
        "last_error": row.last_error,
    }


@router.get("/health")
async def execution_profile_health(
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
):
    """Ping the tenant's dedicated runtime (does not change the profile)."""
    from app.services.freqtrade_client import FreqtradeClient

    tenant_id = _tenant_id(tenant_raw)
    row = db.query(TenantExecutionProfile).filter(
        TenantExecutionProfile.tenant_id == tenant_id
    ).first()
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)
    if row is None or not row.enabled or row.mode != "dedicated" or not row.freqtrade_url:
        if row is not None:
            row.runtime_status = "disabled"
            row.last_health_at = now
            row.last_error = None
            db.commit()
        return {
            "tenant_id": tenant_id, "configured": False, "reachable": False,
            "freqtrade_url": row.freqtrade_url if row else None,
            "runtime_status": "disabled" if row is not None else "unknown",
            "last_health_at": now.isoformat() if row is not None else None,
        }
    reachable = await FreqtradeClient(base_url=row.freqtrade_url).ping()
    row.runtime_status = "healthy" if reachable else "unreachable"
    row.last_health_at = now
    row.last_error = None if reachable else "ping failed"
    db.commit()
    return {
        "tenant_id": tenant_id, "configured": True, "reachable": reachable,
        "freqtrade_url": row.freqtrade_url,
        "runtime_status": row.runtime_status,
        "last_health_at": now.isoformat(),
    }


@router.get("/plan")
def execution_profile_plan(
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
):
    """Dry-run provisioning plan (no container is created)."""
    tenant_id = _tenant_id(tenant_raw)
    row = db.query(TenantExecutionProfile).filter(
        TenantExecutionProfile.tenant_id == tenant_id
    ).first()
    return {
        "tenant_id": tenant_id,
        "container_name": f"alphaloop-ft-{tenant_id}",
        "data_dir": f"/data/tenants/{tenant_id}",
        "suggested_port": 19000 + tenant_id,
        "freqtrade_url": row.freqtrade_url if row else None,
        "max_open_trades": row.max_open_trades if row else 2,
        "has_credentials": bool(row and row.api_password_ct),
        "configured": bool(
            row and row.enabled and row.mode == "dedicated" and row.freqtrade_url
        ),
    }


class RenderConfigRequest(BaseModel):
    dsl: dict
    budget: float
    position_pct: float = 0.02
    max_total_exposure_pct: float = 0.2
    max_daily_loss_pct: float = 0.03
    max_drawdown_pct: float = 0.1
    dry_run: bool = True


def _render_config(db: Session, tenant_id: int, body: "RenderConfigRequest") -> dict:
    from app.schemas.live_small import CapitalPoolParams
    from app.services.crypto_service import CryptoService
    from app.services.live_small.runtime_config import build_tenant_runtime_config

    row = db.query(TenantExecutionProfile).filter(
        TenantExecutionProfile.tenant_id == tenant_id
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Execution profile not configured")

    crypto = CryptoService()
    exchange_key = crypto.decrypt(row.exchange_key_ct, tenant_id=tenant_id) if row.exchange_key_ct else ""
    exchange_secret = crypto.decrypt(row.exchange_secret_ct, tenant_id=tenant_id) if row.exchange_secret_ct else ""
    api_password = crypto.decrypt(row.api_password_ct, tenant_id=tenant_id) if row.api_password_ct else "freqtrade"
    pool = CapitalPoolParams(
        total_budget=body.budget,
        max_position_pct_per_trade=body.position_pct,
        max_total_exposure_pct=body.max_total_exposure_pct,
        max_daily_loss_pct=body.max_daily_loss_pct,
        max_drawdown_pct=body.max_drawdown_pct,
    )
    return build_tenant_runtime_config(
        body.dsl, pool,
        tenant_id=tenant_id,
        dry_run=body.dry_run,
        max_open_trades_cap=row.max_open_trades,
        api_username=row.api_username or "freqtrade",
        api_password=api_password,
        exchange_key=exchange_key,
        exchange_secret=exchange_secret,
    )


@router.post("/render-config")
def render_execution_config(
    body: RenderConfigRequest,
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
):
    """Render the runtime config with decrypted tenant exchange credentials."""
    return _render_config(db, _tenant_id(tenant_raw), body)


@router.post("/write-config")
def write_execution_config(
    body: RenderConfigRequest,
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
    user=Depends(get_optional_user),
):
    """Render and persist the config under the tenant data root (0600)."""
    import hashlib
    import os
    import tempfile
    from pathlib import Path

    from app.config import settings

    tenant_id = _tenant_id(tenant_raw)
    config = _render_config(db, tenant_id, body)
    root = Path(settings.tenant_data_root).resolve()
    directory = (root / str(tenant_id)).resolve()
    if not directory.is_relative_to(root):
        raise HTTPException(status_code=400, detail="Invalid tenant data directory")
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(directory, 0o700)

    payload = __import__("json").dumps(config, indent=2, sort_keys=True).encode()
    fd, tmp_name = tempfile.mkstemp(dir=directory, prefix=".config-", suffix=".json")
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(payload)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp_name, 0o600)
        target = directory / "config.json"
        os.replace(tmp_name, target)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
    digest = hashlib.sha256(payload).hexdigest()
    record_tenant_audit(
        db, tenant_id, "config.write", actor_user_id=actor_id_for(db, user),
        detail={"sha256": digest, "dry_run": config["dry_run"]},
    )
    db.commit()
    return {
        "tenant_id": tenant_id,
        "path": str(target),
        "sha256": digest,
        "dry_run": config["dry_run"],
        "max_open_trades": config["max_open_trades"],
    }


@router.post("/rotate-credentials")
def rotate_execution_credentials(
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
    user=Depends(get_optional_user),
):
    """Rotate the runtime API password. Plaintext is returned exactly once.

    The caller must render a new config and restart the tenant runtime.
    """
    import secrets

    from app.services.crypto_service import CryptoService

    tenant_id = _tenant_id(tenant_raw)
    row = db.query(TenantExecutionProfile).filter(
        TenantExecutionProfile.tenant_id == tenant_id
    ).first()
    if row is None:
        row = TenantExecutionProfile(tenant_id=tenant_id)
        db.add(row)
    password = secrets.token_urlsafe(24)
    row.api_username = row.api_username or "freqtrade"
    row.api_password_ct = CryptoService().encrypt(password, tenant_id=tenant_id)
    record_tenant_audit(
        db, tenant_id, "credentials.rotate", actor_user_id=actor_id_for(db, user),
        detail={"api_username": row.api_username},
    )
    db.commit()
    return {
        "tenant_id": tenant_id,
        "api_username": row.api_username,
        "api_password": password,
        "message": "Render a new config and restart the runtime to apply.",
    }


@router.post("/provision")
def provision_execution_runtime(
    dry_run: bool = True,
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
    user=Depends(get_optional_user),
):
    """Start the tenant container. Defaults to a dry run."""
    from app.services.tenant_runtime_provisioner import get_tenant_runtime_provisioner

    tenant_id = _tenant_id(tenant_raw)
    try:
        result = get_tenant_runtime_provisioner().provision(tenant_id, dry_run=dry_run)
        if not dry_run:
            record_tenant_audit(
                db, tenant_id, "runtime.provision",
                actor_user_id=user.id if user else None,
                detail={"provider": result.get("provider", "docker")},
            )
            db.commit()
        return result
    except FileNotFoundError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))


@router.post("/stop")
def stop_execution_runtime(
    tenant_raw: str | None = Depends(get_current_tenant_id),
    db: Session = Depends(get_db),
    user=Depends(get_optional_user),
):
    from app.services.tenant_runtime_provisioner import get_tenant_runtime_provisioner

    tenant_id = _tenant_id(tenant_raw)
    try:
        result = get_tenant_runtime_provisioner().stop(tenant_id)
        record_tenant_audit(
            db, tenant_id, "runtime.stop",
            actor_user_id=user.id if user else None, detail={},
        )
        db.commit()
        return result
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
