"""SystemSettingsService — CRUD for system_settings table."""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.system_settings import SystemSetting
from app.schemas.system_settings import SystemSettingView


class SystemSettingsService:
    def list(self, db: Session, category: str | None = None) -> list[SystemSettingView]:
        q = db.query(SystemSetting)
        if category:
            q = q.filter(SystemSetting.category == category)
        rows = q.order_by(SystemSetting.key).all()
        return [self._to_view(r) for r in rows]

    def get(self, db: Session, key: str) -> SystemSetting | None:
        return db.query(SystemSetting).filter(SystemSetting.key == key).first()

    def upsert(
        self,
        db: Session,
        key: str,
        value: dict,
        category: str,
        updated_by: str = "api",
    ) -> SystemSetting:
        row = self.get(db, key)
        now = datetime.now(timezone.utc)
        if row is not None:
            row.value = value
            row.category = category
            row.updated_at = now
            row.updated_by = updated_by
            db.flush()
            return row
        row = SystemSetting(
            key=key,
            value=value,
            category=category,
            updated_at=now,
            updated_by=updated_by,
        )
        db.add(row)
        db.flush()
        return row

    def delete(self, db: Session, key: str) -> bool:
        row = self.get(db, key)
        if row is None:
            return False
        db.delete(row)
        db.flush()
        return True

    @staticmethod
    def _to_view(row: SystemSetting) -> SystemSettingView:
        return SystemSettingView(
            id=row.id,
            key=row.key,
            value=row.value or {},
            category=row.category,
            updated_at=row.updated_at or datetime.now(timezone.utc),
            updated_by=row.updated_by,
        )
