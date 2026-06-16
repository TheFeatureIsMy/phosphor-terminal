"""Admin API for provider configuration: CRUD, test, enable/disable, audit."""
from __future__ import annotations

import hashlib
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.provider_config import ProviderAuditLog, ProviderConfig
from app.schemas.provider_config import (
    HealthCheckResultSchema, ProviderConfigPayload, ProviderConfigView,
    ProviderSummaryView, ProviderTestRequest,
)
from app.services.providers.base import ProviderCategory
from app.services.providers.config_service import (
    DuplicateProviderError, ProviderConfigService,
)
from app.services.providers.health_service import ProviderHealthService
from app.services.providers.registry import registry
from app.services.providers.scheduler import ProviderHealthScheduler

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/providers", tags=["admin-providers"])


def _get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _record_audit(db, provider_id, action, actor="api", before_hash=None, after_hash=None, ip=None):
    db.add(ProviderAuditLog(
        provider_id=provider_id, action=action, actor=actor,
        before_hash=before_hash, after_hash=after_hash, ip=ip,
    ))


def _hash_creds(credentials_ct):
    if not credentials_ct:
        return None
    return hashlib.sha256(credentials_ct.encode()).hexdigest()[:8]


@router.get("/categories")
def list_categories() -> dict:
    out = {}
    for cat in ProviderCategory:
        providers = []
        for name in registry.list_providers(cat):
            adapter = registry.get(cat, name)
            providers.append({"name": name, "is_multi_instance": adapter.is_multi_instance})
        out[cat.value] = providers
    return {"categories": out}


@router.get("", response_model=list[ProviderConfigView])
def list_providers(category: str | None = Query(default=None), db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    rows = svc.list(db, category=category)
    return [svc.to_view(r) for r in rows]


@router.get("/{provider_id}", response_model=ProviderConfigView)
def get_provider(provider_id: int, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.get(db, provider_id)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    return svc.to_view(row)


@router.post("", response_model=ProviderConfigView, status_code=201)
def create_provider(payload: ProviderConfigPayload, request: Request, db: Session = Depends(get_db)):
    try:
        category = ProviderCategory(payload.category)
    except ValueError:
        raise HTTPException(status_code=400, detail={"code": "invalid_payload"})
    if not registry.has(category, payload.provider_name):
        raise HTTPException(status_code=400, detail={"code": "unknown_provider"})

    svc = ProviderConfigService()
    try:
        row = svc.upsert(db, payload.model_dump())
        db.commit()
        db.refresh(row)
    except DuplicateProviderError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={"code": "duplicate", "message": str(e)})

    _record_audit(db, row.id, "create", after_hash=_hash_creds(row.credentials_ct), ip=_get_client_ip(request))
    db.commit()
    return svc.to_view(row)


@router.put("/{provider_id}", response_model=ProviderConfigView)
def update_provider(provider_id: int, payload: dict, request: Request, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.get(db, provider_id)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    from app.schemas.provider_config import (
        LLMConfig, CEXConfig, DeXConfig, NotificationConfig,
        MarketDataConfig, OnchainConfig, SocialConfig, NewsConfig,
    )
    schema_map = {
        "llm": LLMConfig, "cex": CEXConfig, "dex": DeXConfig,
        "notification": NotificationConfig, "market_data": MarketDataConfig,
        "onchain": OnchainConfig, "social": SocialConfig, "news": NewsConfig,
    }
    Schema = schema_map[row.category]
    payload_with_id = {**payload, "category": row.category, "provider_name": row.provider_name}
    if row.category != "llm":
        payload_with_id["instance_name"] = None
    else:
        payload_with_id["instance_name"] = row.instance_name
    validated = Schema.model_validate(payload_with_id)
    before_hash = _hash_creds(row.credentials_ct)
    try:
        svc.upsert(db, validated.model_dump())
        db.commit()
    except DuplicateProviderError:
        db.rollback()
        raise HTTPException(status_code=409, detail={"code": "duplicate"})
    db.refresh(row)
    after_hash = _hash_creds(row.credentials_ct)
    _record_audit(db, row.id, "update", before_hash=before_hash, after_hash=after_hash, ip=_get_client_ip(request))
    db.commit()
    return svc.to_view(row)


@router.delete("/{provider_id}", status_code=204)
def delete_provider(provider_id: int, request: Request, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    if not svc.delete(db, provider_id):
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    _record_audit(db, provider_id, "delete", ip=_get_client_ip(request))
    db.commit()


@router.post("/{provider_id}/test", response_model=HealthCheckResultSchema)
async def test_provider(provider_id: int, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.get(db, provider_id)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    health = ProviderHealthService(registry=registry)
    result = await health.test_from_row(db, row)
    db.commit()
    return HealthCheckResultSchema(
        success=result.success, status=result.status.value,
        latency_ms=result.latency_ms, error=result.error,
        rate_limit=result.rate_limit.model_dump() if result.rate_limit else None,
        checked_at=result.checked_at,
    )


@router.post("/test", response_model=HealthCheckResultSchema)
async def test_ephemeral(body: ProviderTestRequest):
    health = ProviderHealthService(registry=registry)
    result = await health.test_ephemeral(
        category=body.category, provider_name=body.provider_name,
        credentials=body.credentials or {}, config=body.config,
    )
    return HealthCheckResultSchema(
        success=result.success, status=result.status.value,
        latency_ms=result.latency_ms, error=result.error,
        rate_limit=result.rate_limit.model_dump() if result.rate_limit else None,
        checked_at=result.checked_at,
    )


@router.post("/{provider_id}/enable", response_model=ProviderConfigView)
def enable_provider(provider_id: int, request: Request, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.set_enabled(db, provider_id, True)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    db.commit()
    _record_audit(db, row.id, "enable", ip=_get_client_ip(request))
    db.commit()
    return svc.to_view(row)


@router.post("/{provider_id}/disable", response_model=ProviderConfigView)
def disable_provider(provider_id: int, request: Request, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.set_enabled(db, provider_id, False)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    db.commit()
    _record_audit(db, row.id, "disable", ip=_get_client_ip(request))
    db.commit()
    return svc.to_view(row)


@router.post("/{provider_id}/rotate-credentials", status_code=501)
def rotate_credentials(provider_id: int):
    raise HTTPException(status_code=501, detail={"code": "not_implemented"})


@router.get("/{provider_id}/audit-log")
def get_audit_log(provider_id: int, limit: int = Query(default=50, ge=1, le=500), db: Session = Depends(get_db)):
    rows = db.query(ProviderAuditLog).filter(
        ProviderAuditLog.provider_id == provider_id
    ).order_by(ProviderAuditLog.created_at.desc()).limit(limit).all()
    return [{
        "id": r.id, "action": r.action, "actor": r.actor,
        "before_hash": r.before_hash, "after_hash": r.after_hash,
        "ip": r.ip, "created_at": r.created_at.isoformat() if r.created_at else None,
    } for r in rows]


@router.get("/health-summary", response_model=ProviderSummaryView)
def health_summary(db: Session = Depends(get_db)):
    rows = db.query(ProviderConfig).all()
    by_category = {}
    total_active = total_error = total_disabled = total_configured = 0
    for r in rows:
        by_category[r.category] = by_category.get(r.category, 0) + 1
        if r.status == "active": total_active += 1
        if r.status == "error": total_error += 1
        if not r.enabled: total_disabled += 1
        if r.credential_status == "configured": total_configured += 1
    return ProviderSummaryView(
        by_category=by_category, total_active=total_active, total_error=total_error,
        total_disabled=total_disabled, total_configured=total_configured,
        total=len(rows), checked_at=datetime.now(timezone.utc),
    )


@router.post("/health-tick")
async def health_tick():
    sched = ProviderHealthScheduler()
    tested = await sched.tick_once()
    return {"tested": tested}
