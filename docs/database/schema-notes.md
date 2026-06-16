# Database Schema Notes — Provider Adapter Foundation

ER overview and column-level documentation for the new `provider_configs`
and `provider_audit_logs` tables, plus the soft FK added to
`ai_usage_logs`.

## ER Diagram (text)

```
┌──────────────────────────────┐
│       provider_configs        │
│──────────────────────────────│
│ id              PK           │
│ category                     │
│ provider_name                │
│ instance_name                │
│ config (JSON)                │
│ credentials_ct               │  ← Fernet ciphertext
│ credentials_fields (JSON)    │
│ enabled, is_active           │
│ priority                     │
│ status, credential_status    │
│ last_sync_at, last_error     │
│ latency_ms                   │
│ rate_limit_remaining         │
│ rate_limit_reset_at          │
│ created_at, updated_at       │
└──────────────┬───────────────┘
               │ ON DELETE CASCADE
               ▼
┌──────────────────────────────┐
│     provider_audit_logs       │
│──────────────────────────────│
│ id              PK           │
│ provider_id       FK         │
│ action                       │
│ actor, ip                    │
│ before_hash, after_hash      │  ← SHA-256-8 of creds_ct
│ created_at                   │
└──────────────────────────────┘

┌──────────────────────────────┐        ┌──────────────────────────────┐
│       ai_usage_logs          │        │       provider_configs        │
│ (existing; +FK this round)   │        │                               │
│──────────────────────────────│        │                               │
│ id              PK           │        │                               │
│ provider        (existing)   │        │                               │
│ model           (existing)   │        │                               │
│ service         (existing)   │        │                               │
│ tokens_used     (existing)   │        │                               │
│ latency_ms      (existing)   │        │                               │
│ created_at      (existing)   │        │                               │
│ provider_config_id  FK-new   │──┐     │                               │
└──────────────────────────────┘  │     │                               │
                                  │  ON DELETE SET NULL              │
                                  └────→│ id PK                          │
                                        └──────────────────────────────┘
```

## `provider_configs` (new)

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | Integer | no | autoincrement | PK |
| `category` | String | no | — | one of 8 values |
| `provider_name` | String | no | — | matches a registered provider name |
| `instance_name` | String | yes | NULL | required for LLM; enforced NULL otherwise |
| `config` | JSON | no | `{}` | non-sensitive Pydantic-validated config |
| `credentials_ct` | Text | yes | NULL | Fernet-encrypted JSON of credentials dict |
| `credentials_fields` | JSON | yes | NULL | sorted list of credential dict keys |
| `enabled` | Boolean | no | `true` | admin on/off |
| `is_active` | Boolean | no | `false` | derived: `True iff status='active'` |
| `priority` | Integer | no | 0 | LLM routing priority |
| `status` | String | no | `'unknown'` | derived enum |
| `credential_status` | String | no | `'missing'` | `missing/configured/expired/invalid` |
| `last_sync_at` | DateTime | yes | NULL | last `test_connection` time |
| `last_error` | String | yes | NULL | truncated to 200 chars |
| `latency_ms` | Integer | yes | NULL | last test latency |
| `rate_limit_remaining` | Integer | yes | NULL | from response header |
| `rate_limit_reset_at` | DateTime | yes | NULL | from response header |
| `created_at` | DateTime | no | server now | |
| `updated_at` | DateTime | no | server now | on update |

### Status values (derived)

The `status` column is updated by `ProviderHealthService._derive_status`
after each connection test. The status derivation chain is:

1. If `enabled = False` → `disabled`
2. If `last_sync_at` is NULL → `unknown`
3. If `last_sync_at` is older than 24 hours → `unknown`
4. If test failed with auth-related error (401, 403, expired, invalid) → `inactive`
5. If test failed with any other error → `error`
6. If test succeeded but `rate_limit_remaining = 0` → `rate_limited`
7. If test succeeded with remaining rate limit → `active`

The `is_active` boolean is a denormalized convenience: `True` iff `status = 'active'`.
It exists to support efficient DB queries for the scheduler (e.g., "find all active
providers that need health checks").

### Credential status lifecycle

```
                        ┌──────────┐
                        │ missing   │ ← initial state (no credentials stored)
                        └─────┬─────┘
                              │ upsert with credentials
                              ▼
                        ┌──────────────┐
                        │ configured   │ ← credentials present and decryptable
                        └──────┬───────┘
                               │ test fails with auth error
                               ▼
                        ┌──────────┐
                        │ invalid   │ ← credentials rejected by remote
                        └──────────┘
                               │
                               │ upsert with new credentials
                               ▼
                        ┌──────────────┐
                        │ configured   │ ← re-configured
                        └──────────────┘
                        ┌──────────┐
                        │ expired   │ ← future: OAuth token expiry detection
                        └──────────┘
```

`expired` is reserved for future OAuth refresh flows. In the initial
implementation, only `missing`, `configured`, and `invalid` are
actively set by the health service.

### Constraints

- `ck_instance_name_by_category`:
  `(category = 'llm' AND instance_name IS NOT NULL) OR (category != 'llm' AND instance_name IS NULL)`

### Indices

- `ix_provider_config_category` (`category`)
- `ix_provider_config_provider_name` (`provider_name`)
- `ix_provider_config_cat_name` (composite: `category`, `provider_name`)
- `ix_provider_config_enabled` (`enabled`)

### Uniqueness

Enforced at the service layer (`ProviderConfigService.upsert`):

- LLM: `WHERE category = ? AND provider_name = ? AND instance_name = ?`
- Other: `WHERE category = ? AND provider_name = ? AND instance_name IS NULL`

A hit raises `DuplicateProviderError` → HTTP 409 `code="duplicate"`.

**Why not a DB-level unique constraint?** SQLAlchemy/PostgreSQL partial
unique indexes have DB-vendor-specific syntax that complicates the
SQLite dev path. The CheckConstraint guarantees that the search
predicate finds only valid candidates, so the service-layer check is
race-free under SERIALIZABLE isolation (and acceptable under READ
COMMITTED for this dev-phase product).

## `provider_audit_logs` (new)

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | Integer | no | autoincrement | PK |
| `provider_id` | Integer | no | — | FK to `provider_configs.id` ON DELETE CASCADE |
| `action` | String | no | — | `create/update/enable/disable/test/rotate/delete` |
| `actor` | String | yes | NULL | who triggered (`api`/`cli`/etc) |
| `before_hash` | String | yes | NULL | SHA-256-8 of pre-state `credentials_ct` |
| `after_hash` | String | yes | NULL | SHA-256-8 of post-state `credentials_ct` |
| `ip` | String | yes | NULL | client IP from request |
| `created_at` | DateTime | no | server now | indexed |

### Indices

- `ix_provider_audit_logs_provider_id` (`provider_id`)
- `ix_provider_audit_logs_created_at` (`created_at`)

## `ai_usage_logs` (existing, +FK)

A nullable `provider_config_id` FK is added. `ON DELETE SET NULL` so
deleting a config preserves historical usage records.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `provider_config_id` | Integer | yes | FK to `provider_configs.id` ON DELETE SET NULL |

## `ai_provider_configs` (dropped)

The legacy table is dropped in this migration. It had:

| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | |
| `provider` | String | `openai/anthropic/ollama` |
| `api_key_encrypted` | String | Fernet-encrypted single key |
| `base_url` | String | |
| `model` | String | |
| `is_active` | Boolean | |
| `priority` | Integer | |
| `created_at`, `updated_at` | DateTime | |

It could not represent:
- Multi-instance LLM (one row per provider_name)
- Multi-category (CEX, notification, etc.)
- Rate-limit runtime state
- Audit log
- Provider enable/disable independent of is_active

## Alembic migration

File: `backend/alembic/versions/2026_06_16_xxxx_provider_foundation.py`

Order of operations:

1. Add nullable `provider_config_id` to `ai_usage_logs` + FK.
2. Create `provider_configs` + indices.
3. Create `provider_audit_logs` + indices.
4. Drop `ai_provider_configs`.

The `downgrade` reverses in opposite order. The migration is not
data-preserving — the dev environment accepts that.

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` §6
- API contracts: `docs/backend/api-contracts.md`
- Configuration model: `docs/settings/configuration-model.md`
