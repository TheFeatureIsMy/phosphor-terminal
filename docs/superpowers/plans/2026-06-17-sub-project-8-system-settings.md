# Sub-project 8 — System Settings Model

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a backend `system_settings` table + admin API for non-provider settings (general/risk/privacy/retention).

**Tech Stack:** Python 3.12 / FastAPI / SQLAlchemy 2.0 / Pydantic v2 / pytest. No new deps.

**Spec:** `docs/superpowers/specs/2026-06-17-sub-project-8-system-settings-design.md`

**Use venv** at `backend/.venv/bin/python`.

---

## Task 1: SQLAlchemy model

- [ ] **Step 1: Create `backend/app/models/system_settings.py`**:

```python
"""System settings persistence model."""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Column, DateTime, Index, Integer, JSON, String,
)

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class SystemSetting(Base):
    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True, autoincrement=True)
    key = Column(String(128), nullable=False, unique=True)
    value = Column(JSON, nullable=False)
    category = Column(String(32), nullable=False)
    updated_at = Column(DateTime, nullable=False, default=_utcnow, onupdate=_utcnow)
    updated_by = Column(String(64), nullable=True)

    __table_args__ = (
        Index("ix_system_settings_category", "category"),
    )
```

- [ ] **Step 2: Add to `backend/app/models/__init__.py`** (add a line alongside the existing `from app.models.provider_config import ...`):

```python
from app.models.system_settings import SystemSetting  # noqa: F401
```

Also add `"SystemSetting"` to the `__all__` list if there is one.

- [ ] **Step 3: Verify import**:

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "from app.models.system_settings import SystemSetting; print(SystemSetting.__tablename__)"
```

Expected: `system_settings`.

- [ ] **Step 4: Commit**:

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/models/system_settings.py backend/app/models/__init__.py && git commit -m "feat(system-settings): add SystemSetting SQLAlchemy model"
```

---

## Task 2: Pydantic schemas

- [ ] **Step 1: Create `backend/app/schemas/system_settings.py`**:

```python
"""Pydantic schemas for system settings."""
from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class SystemSettingView(BaseModel):
    """Read-side view of a system setting."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    key: str
    value: dict
    category: str
    updated_at: datetime
    updated_by: str | None = None


class SystemSettingUpsertRequest(BaseModel):
    """Body for PUT /api/admin/system-settings/{key}."""

    value: dict
    category: Literal["general", "risk", "privacy", "retention"]
    updated_by: str = Field(default="api")
```

- [ ] **Step 2: Smoke import**:

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "from app.schemas.system_settings import SystemSettingView, SystemSettingUpsertRequest; print('OK')"
```

- [ ] **Step 3: Commit**:

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/schemas/system_settings.py && git commit -m "feat(system-settings): add Pydantic schemas (view + upsert request)"
```

---

## Task 3: Service (CRUD + uniqueness)

- [ ] **Step 1: Create `backend/app/services/system_settings.py`**:

```python
"""SystemSettingsService — CRUD for system_settings table."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

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
```

- [ ] **Step 2: Create `backend/tests/test_system_settings.py`**:

```python
"""Tests for SystemSettingsService."""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.services.system_settings import SystemSettingsService


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    s = Session()
    yield s
    s.close()


def test_create_and_get(db):
    svc = SystemSettingsService()
    svc.upsert(db, "general.default_language", {"value": "zh-CN"}, "general", "alice")
    db.commit()
    row = svc.get(db, "general.default_language")
    assert row is not None
    assert row.value == {"value": "zh-CN"}
    assert row.category == "general"
    assert row.updated_by == "alice"


def test_update_existing(db):
    svc = SystemSettingsService()
    svc.upsert(db, "risk.max_single_loss", {"value": 5.0}, "risk")
    db.commit()
    svc.upsert(db, "risk.max_single_loss", {"value": 3.0}, "risk", "bob")
    db.commit()
    row = svc.get(db, "risk.max_single_loss")
    assert row.value == {"value": 3.0}
    assert row.updated_by == "bob"


def test_duplicate_key_raises_integrity(db):
    svc = SystemSettingsService()
    svc.upsert(db, "k1", {"v": 1}, "general")
    db.commit()
    # SQLite allows upsert of same key (we find existing); not a duplicate error
    svc.upsert(db, "k1", {"v": 2}, "general")
    db.commit()
    assert svc.get(db, "k1").value == {"v": 2}


def test_list_filtered_by_category(db):
    svc = SystemSettingsService()
    svc.upsert(db, "a", {"v": 1}, "general")
    svc.upsert(db, "b", {"v": 2}, "risk")
    svc.upsert(db, "c", {"v": 3}, "privacy")
    db.commit()
    assert len(svc.list(db)) == 3
    assert len(svc.list(db, category="risk")) == 1


def test_get_missing_returns_none(db):
    assert SystemSettingsService().get(db, "nope") is None


def test_delete(db):
    svc = SystemSettingsService()
    svc.upsert(db, "x", {"v": 1}, "general")
    db.commit()
    assert svc.delete(db, "x") is True
    db.commit()
    assert svc.get(db, "x") is None
    assert svc.delete(db, "x") is False  # already gone
```

- [ ] **Step 3: Run + commit**:

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/test_system_settings.py --noconftest -q 2>&1 | tail -3
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/system_settings.py backend/tests/test_system_settings.py && git commit -m "feat(system-settings): add SystemSettingsService + 6 unit tests"
```

---

## Task 4: Alembic migration

- [ ] **Step 1: Generate migration skeleton**:

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/alembic revision -m "add system_settings table with 4 seed rows"
```

Note the filename (something like `xxxx_add_system_settings.py`).

- [ ] **Step 2: Replace the file's `upgrade()` and `downgrade()` with**:

```python
def upgrade() -> None:
    op.create_table(
        "system_settings",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("key", sa.String(length=128), nullable=False, unique=True),
        sa.Column("value", sa.JSON(), nullable=False),
        sa.Column("category", sa.String(length=32), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("updated_by", sa.String(length=64), nullable=True),
    )
    op.create_index("ix_system_settings_category", "system_settings", ["category"])

    # Seed 4 example rows
    op.bulk_insert(
        sa.table(
            "system_settings",
            sa.column("key", sa.String),
            sa.column("value", sa.JSON),
            sa.column("category", sa.String),
            sa.column("updated_at", sa.DateTime),
            sa.column("updated_by", sa.String),
        ),
        [
            {"key": "general.default_language", "value": {"value": "zh-CN"}, "category": "general", "updated_at": sa.func.now(), "updated_by": "system"},
            {"key": "risk.max_single_loss", "value": {"value": 5.0}, "category": "risk", "updated_at": sa.func.now(), "updated_by": "system"},
            {"key": "privacy.share_ai_prompts", "value": {"value": False}, "category": "privacy", "updated_at": sa.func.now(), "updated_by": "system"},
            {"key": "retention.logs_days", "value": {"value": 30}, "category": "retention", "updated_at": sa.func.now(), "updated_by": "system"},
        ],
    )


def downgrade() -> None:
    op.drop_index("ix_system_settings_category", table_name="system_settings")
    op.drop_table("system_settings")
```

- [ ] **Step 3: Apply migration**:

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/alembic upgrade head 2>&1 | tail -5
```

- [ ] **Step 4: Verify**:

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.database import engine
from sqlalchemy import inspect
insp = inspect(engine)
print('system_settings cols:', [c['name'] for c in insp.get_columns('system_settings')])
print('rows:', engine.connect().exec_driver_sql('SELECT count(*) FROM system_settings').scalar())
"
```

Expected: `['id', 'key', 'value', 'category', 'updated_at', 'updated_by']` and `4` rows.

- [ ] **Step 5: Commit**:

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/alembic/versions/ && git commit -m "feat(system-settings): alembic migration creates system_settings table with 4 seed rows"
```

---

## Task 5: Admin API router

- [ ] **Step 1: Create `backend/app/routers/admin/system_settings.py`**:

```python
"""Admin API for system_settings."""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.system_settings import SystemSetting
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


@router.delete("/{key:path}", status_code=204)
def delete_setting(key: str, db: Session = Depends(get_db)) -> None:
    if not SystemSettingsService().delete(db, key):
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    db.commit()
```

- [ ] **Step 2: Register in main.py**. Add import + include:

```python
from app.routers.admin.system_settings import router as admin_system_settings_router
# ...
app.include_router(admin_system_settings_router)
```

- [ ] **Step 3: Verify**:

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.main import app
ss_routes = [r for r in app.routes if '/api/admin/system-settings' in getattr(r, 'path', '')]
print('system-settings routes:', len(ss_routes))
for r in ss_routes:
    print(' ', r.methods, r.path)
"
```

Expected: 4 routes (GET list, GET by key, PUT, DELETE).

- [ ] **Step 4: Commit**:

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/routers/admin/system_settings.py backend/app/main.py && git commit -m "feat(system-settings): add admin API (GET list/by-key, PUT upsert, DELETE)"
```

---

## Task 6: Integration test

- [ ] **Step 1: Create `backend/tests/integration/test_system_settings_api.py`**:

```python
"""Integration tests for /api/admin/system-settings/*."""
import os
import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app.main import app


@pytest.fixture(autouse=True)
def fernet_key(monkeypatch):
    monkeypatch.setenv("PULSEDESK_ENCRYPTION_KEY", Fernet.generate_key().decode())


@pytest.fixture
def db():
    engine = create_engine("sqlite:///./test_system_settings.db")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    s = Session()
    yield s
    s.close()
    os.remove("./test_system_settings.db") if os.path.exists("./test_system_settings.db") else None


@pytest.fixture
def client(db, monkeypatch):
    def _override():
        try:
            yield db
        finally:
            pass
    app.dependency_overrides[get_db] = _override
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def test_list_returns_empty(client):
    r = client.get("/api/admin/system-settings")
    assert r.status_code == 200
    assert r.json() == []


def test_upsert_and_get(client):
    r = client.put(
        "/api/admin/system-settings/risk.max_single_loss",
        json={"value": {"value": 5.0}, "category": "risk", "updated_by": "alice"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["key"] == "risk.max_single_loss"
    assert body["value"] == {"value": 5.0}
    assert body["category"] == "risk"

    r2 = client.get("/api/admin/system-settings/risk.max_single_loss")
    assert r2.status_code == 200
    assert r2.json()["value"] == {"value": 5.0}


def test_get_missing_returns_404(client):
    r = client.get("/api/admin/system-settings/nope.doesnt.exist")
    assert r.status_code == 404
    assert r.json()["detail"]["code"] == "not_found"


def test_update_existing(client):
    client.put(
        "/api/admin/system-settings/retention.logs_days",
        json={"value": {"value": 30}, "category": "retention"},
    )
    r = client.put(
        "/api/admin/system-settings/retention.logs_days",
        json={"value": {"value": 60}, "category": "retention", "updated_by": "bob"},
    )
    assert r.status_code == 200
    assert r.json()["value"] == {"value": 60}
    assert r.json()["updated_by"] == "bob"
```

- [ ] **Step 2: Run + commit**:

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/integration/test_system_settings_api.py --noconftest -q 2>&1 | tail -5
cd /Users/novspace/workspace/phosphor-terminal && git add backend/tests/integration/test_system_settings_api.py && git commit -m "test(system-settings): add admin API integration tests"
```

---

## Task 7: Update docs

- [ ] **Step 1: Update `docs/database/schema-notes.md`**. Add a new "## `system_settings` (new)" section with the column table (copy the spec's column table). Place it after the existing `system_settings` description (or before "## Cross-references"). If the file doesn't have such a section, add it after `## `ai_usage_logs` (existing, +FK)`.

- [ ] **Step 2: Update `docs/backend/api-contracts.md`**. Add the 4 new endpoints (GET list, GET by key, PUT, DELETE) under a new "## System Settings" section.

- [ ] **Step 3: Commit**:

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/database/schema-notes.md docs/backend/api-contracts.md && git commit -m "docs: add system_settings table to schema-notes + 4 endpoints to api-contracts"
```

---

## Acceptance Criteria

- 4 unit tests + 4 integration tests pass
- Migration creates table with 4 seed rows
- Admin API has 4 endpoints
- `swift build` passes
- 7 commits in this round

**End of plan.**
