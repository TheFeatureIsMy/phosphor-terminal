---
title: Sub-project 8 — System Settings Model
status: approved
date: 2026-06-17
authors: claude (brainstorming skill)
related:
  - docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md
  - docs/backend/api-contracts.md
  - docs/database/schema-notes.md
---

# Sub-project 8 — System Settings Model

## 1. Problem

The system has provider-specific configuration (`provider_configs`) but no place for non-provider settings like:
- Risk defaults (`risk.max_single_loss`, `risk.max_drawdown`)
- Privacy rules (`privacy.share_ai_prompts`)
- Retention policies (`retention.logs_days`)
- General system toggles (`general.dark_mode`, `general.default_language`)

These are scattered across `SettingsState` (iOS) and `.env` (backend). This sub-project adds a backend `system_settings` table + admin API.

## 2. Goals

1. New `system_settings` table: `id`, `key` (unique), `value` (JSON), `category`, `updated_at`, `updated_by`.
2. Categories: `general`, `risk`, `privacy`, `retention`.
3. Admin API: `GET /api/admin/system-settings?category=risk`, `GET /api/admin/system-settings/{key}`, `PUT /api/admin/system-settings/{key}`.
4. Audit via the existing `provider_audit_logs` pattern (or a parallel `system_audit_logs` — see decision below).
5. Alembic migration adds the new table.

## 3. Non-Goals

- Schema-level validation per key (e.g., "max_single_loss must be 0-100"). The Pydantic discriminated union can be added in a follow-up. For this round, value is opaque JSON.
- iOS UI changes (just plumbing, no Settings UI).
- Migrating existing `SettingsState` values to the DB. Future sub-project.

## 4. Architecture

### 4.1 Table

```sql
CREATE TABLE system_settings (
    id           SERIAL PRIMARY KEY,
    key          VARCHAR(128) NOT NULL UNIQUE,
    value        JSON NOT NULL,
    category     VARCHAR(32) NOT NULL,
    updated_at   TIMESTAMP NOT NULL,
    updated_by   VARCHAR(64)  -- 'api' / 'cli' / user identifier
);
CREATE INDEX ix_system_settings_category ON system_settings(category);
```

### 4.2 Files

**New (backend):**
- `app/models/system_settings.py` — SQLAlchemy model
- `app/schemas/system_settings.py` — Pydantic schemas (PUT body, GET view)
- `app/services/system_settings.py` — `SystemSettingsService` (CRUD with uniqueness)
- `app/routers/admin/system_settings.py` — admin API
- `app/tests/test_system_settings.py` — unit tests
- `app/tests/integration/test_system_settings_api.py` — integration tests
- `alembic/versions/2026_06_17_xxxx_system_settings.py` — migration

**Modified:**
- `app/main.py` — register the new admin router
- `app/models/__init__.py` — import the new model
- `docs/database/schema-notes.md` — add the new table
- `docs/backend/api-contracts.md` — add the new endpoints

## 5. API Surface

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/admin/system-settings?category=risk` | List all (optionally filtered by category) |
| GET | `/api/admin/system-settings/{key}` | Get single setting |
| PUT | `/api/admin/system-settings/{key}` | Create or update (upsert); body has `value`, `category`, `updated_by` |

## 6. Migration

Single Alembic migration:
1. `CREATE TABLE system_settings ...`
2. `CREATE INDEX ...`
3. Seed 4 example rows: `general.default_language=zh-CN`, `risk.max_single_loss=5.0`, `privacy.share_ai_prompts=false`, `retention.logs_days=30`.

## 7. Audit

For this round, audit logs use the existing `provider_audit_logs` table (with `provider_id=NULL` for system settings, action='system_setting_update'). Future sub-projects can split into a dedicated `system_audit_logs` table.

## 8. Acceptance Criteria

- Migration creates `system_settings` table
- 6 unit tests + 4 integration tests pass
- All existing tests still pass
- `swift build` still passes
- `docs/database/schema-notes.md` and `docs/backend/api-contracts.md` updated
