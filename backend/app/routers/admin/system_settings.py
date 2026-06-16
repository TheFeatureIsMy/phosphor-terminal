"""Admin API for system_settings."""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.system_settings import SystemSettingUpsertRequest, SystemSettingView
from app.services.system_settings import SystemSettingsService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/system-settings", tags=["admin-system-settings"])


@router.get("", response_model=list[SystemSettingView])
def list_settings(
    category: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> list[SystemSettingView]:
    return SystemSettingsService().list(db, category=category)


@router.get("/{key:path}", response_model=SystemSettingView)
def get_setting(key: str, db: Session = Depends(get_db)) -> SystemSettingView:
    row = SystemSettingsService().get(db, key)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    return SystemSettingsService._to_view(row)


@router.put("/{key:path}", response_model=SystemSettingView)
def upsert_setting(
    key: str,
    body: SystemSettingUpsertRequest,
    db: Session = Depends(get_db),
) -> SystemSettingView:
    row = SystemSettingsService().upsert(
        db,
        key=key,
        value=body.value,
        category=body.category,
        updated_by=body.updated_by,
    )
    db.commit()
    db.refresh(row)
    return SystemSettingsService._to_view(row)


@router.delete("/{key:path}", status_code=204, response_model=None)
def delete_setting(key: str, db: Session = Depends(get_db)) -> None:
    if not SystemSettingsService().delete(db, key):
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    db.commit()
