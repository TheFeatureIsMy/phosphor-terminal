# Configuration Model — Provider Adapter Foundation

The provider configuration system uses a single `provider_configs` table
backed by a Pydantic discriminated union. In addition, non-provider
configuration (general / risk / privacy / retention) is stored in a
separate `system_settings` table. This document describes the schema,
the validation flow, the encryption boundary, and the audit trail for
both systems.

## Tables

### `provider_configs`

Single table for all 8 categories. Column-by-column:

| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | autoincrement |
| `category` | String | one of `llm/cex/dex/notification/market_data/onchain/social/news` |
| `provider_name` | String | the registered provider name (e.g. `binance`) |
| `instance_name` | String? | required for LLM; NULL for all other categories |
| `config` | JSON | non-sensitive configuration (Pydantic-validated) |
| `credentials_ct` | Text? | Fernet-encrypted JSON of the credentials dict |
| `credentials_fields` | JSON? | list of credential field names (e.g. `["api_key"]`) |
| `enabled` | Boolean | admin on/off (default true) |
| `is_active` | Boolean | derived: `True iff status='active'` |
| `priority` | Integer | LLM routing priority; 0 for other categories |
| `status` | String | derived enum: `unknown/active/inactive/error/rate_limited/disabled` |
| `credential_status` | String | `missing/configured/expired/invalid` |
| `last_sync_at` | DateTime? | last test_connection time |
| `last_error` | String? | truncated to 200 chars |
| `latency_ms` | Integer? | last test latency |
| `rate_limit_remaining` | Integer? | from response header |
| `rate_limit_reset_at` | DateTime? | from response header |
| `created_at` | DateTime | server-side |
| `updated_at` | DateTime | on update |

### Constraints

- `ck_instance_name_by_category`: LLM must have `instance_name`; others must NOT.
- Uniqueness is enforced at the service layer:
  - LLM: `(category, provider_name, instance_name)` must be unique
  - Other: `(category, provider_name, instance_name IS NULL)` must be unique
- Indices: `ix_provider_config_category`, `ix_provider_config_provider_name`, `ix_provider_config_cat_name` (composite), `ix_provider_config_enabled`.

### `provider_audit_logs`

Records every config-changing action:

| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | |
| `provider_id` | Integer FK | CASCADE on delete |
| `action` | String | `create/update/enable/disable/test/rotate/delete` |
| `actor` | String? | who triggered (e.g. `api`) |
| `before_hash` | String? | SHA-256-8 of pre-state `credentials_ct` (never plaintext) |
| `after_hash` | String? | SHA-256-8 of post-state `credentials_ct` |
| `ip` | String? | client IP from request |
| `created_at` | DateTime | server-side |

### `ai_usage_logs` (existing; soft FK added)

A nullable `provider_config_id` FK links each usage record back to the
config that produced it. The FK uses `ON DELETE SET NULL` so deleting a
config does not lose historical usage data.

## Pydantic Discriminated Union

`app.schemas.provider_config.ProviderConfigPayload` is the canonical
input type for create/update endpoints. It is built as:

```python
ProviderConfigPayload = Annotated[
    LLMConfig | CEXConfig | DeXConfig | NotificationConfig
    | MarketDataConfig | OnchainConfig | SocialConfig | NewsConfig,
    Field(discriminator="category"),
]
```

Each subclass of `ProviderConfigBase` overrides the `category` field
with a `Literal[...]` so Pydantic picks the right validator.

### `LLMConfig`

- `instance_name: str` (required)
- `config: dict` (e.g. `{"model": "gpt-4o"}`)
- `credentials: dict | None` (e.g. `{"api_key": "sk-..."}`)

### `CEXConfig`

- `config: dict` (e.g. `{"base_url": "https://api.binance.com"}`)
- `credentials: dict | None` (e.g. `{"api_key", "api_secret", "passphrase"}`)

### `DeXConfig`

- `config: dict` (e.g. `{"chain": "arbitrum", "pool": "ETH-USDC"}`)
- `credentials: dict | None` (e.g. `{"private_key": "0x..."}`)

### `NotificationConfig`

- `config: dict` (e.g. `{"chat_id": "-1001234567890"}`)
- `credentials: dict | None` (e.g. `{"bot_token": "123:ABC"}`)

### `MarketDataConfig`

- `config: dict` (e.g. `{"symbols": ["BTC/USDT", "ETH/USDT"]}`)
- `credentials: dict | None` (e.g. `{"api_key": "..."}`)

### `OnchainConfig`

- `config: dict` (e.g. `{"chains": ["ethereum", "solana"]}`)
- `credentials: dict | None` (e.g. `{"api_key": "..."}`)

### `SocialConfig`

- `config: dict` (e.g. `{"keywords": ["BTC", "crypto"]}`)
- `credentials: dict | None` (e.g. `{"api_key": "..."}`)

### `NewsConfig`

- `config: dict` (e.g. `{"categories": ["crypto", "defi"]}`)
- `credentials: dict | None` (e.g. `{"api_key": "..."}`)

## View Model

`ProviderConfigView` is what every read endpoint returns. **It never
contains plaintext credentials.** Field-by-field:

| Field | Source | Notes |
|---|---|---|
| `id` | `provider_configs.id` | |
| `category` | same | |
| `provider_name` | same | |
| `instance_name` | same | NULL for non-LLM |
| `enabled` | same | |
| `is_active` | same | derived |
| `priority` | same | |
| `status` | same | derived |
| `credential_status` | same | |
| `credentials_fields` | `credentials_fields` JSON | e.g. `["api_key"]` |
| `last_sync_at` | same | |
| `last_error` | same | truncated to 200 chars |
| `latency_ms` | same | |
| `rate_limit_remaining` | same | from response header |
| `rate_limit_reset_at` | same | from response header |
| `config` | `config` JSON | masked via `adapter.mask_config()` |
| `updated_at` | same | |

## Encryption

`app/services/crypto_service.py:CryptoService` (existing) is the single
encryption boundary.

**Write path** (in `ProviderConfigService.upsert`):
1. Receive plaintext `credentials` in payload.
2. `json.dumps(creds, sort_keys=True, ensure_ascii=False)`.
3. `CryptoService.encrypt(payload)` → `credentials_ct`.
4. `sorted(creds.keys())` → `credentials_fields`.
5. Set `credential_status="configured"`.

**Read path** (in `ProviderConfigService.decrypt_credentials`):
1. `CryptoService.decrypt(credentials_ct)` → JSON string.
2. `json.loads(...)` → dict.
3. **Never** returned to the iOS client; only used inside
   `ProviderHealthService.test_from_row` to call the adapter.

**Read-side fallback** (dev mode without `PULSEDESK_ENCRYPTION_KEY`):
`CryptoService` runs in passthrough mode. This is acceptable for dev but
**must not** be used in production.

**Tampered ciphertext**: `CryptoService.decrypt` returns the input
unchanged on failure (with a debug log). `ProviderConfigService` returns
`None` on JSON decode failure, and the row's `credential_status` is set
to `invalid` by `ProviderHealthService`.

## Status Derivation

`health_service._derive_status` is a pure function:

| Input | Output |
|---|---|
| `enabled=False` | `disabled` |
| `last_sync` is None | `unknown` |
| `last_sync` > 24h ago | `unknown` |
| `success=False` and error contains `401/403/expired/invalid` | `inactive` |
| `success=False` (other) | `error` |
| `success=True` and `rate_limit.remaining == 0` | `rate_limited` |
| `success=True` (other) | `active` |

## Multi-Instance Rule

Only LLM supports multiple instances. For LLM, the tuple
`(category, provider_name, instance_name)` is unique. For all other
categories, the tuple `(category, provider_name)` is unique (and
`instance_name` is enforced NULL by the `ck_instance_name_by_category`
check constraint).

The registry (`ProviderRegistry`) validates at registration time that
`is_multi_instance` matches the category rule (LLM=True, all others=False).

## Migration (one-time)

The Alembic migration `2026_06_16_xxxx_provider_foundation.py`:
1. Adds nullable `provider_config_id` FK to `ai_usage_logs`.
2. Creates `provider_configs` and `provider_audit_logs`.
3. Drops `ai_provider_configs` (no production data to preserve).

The migration is **not reversible in production** without restoring a
backup of `ai_provider_configs`. In dev, `alembic downgrade -1` brings
the schema back, but no rows.

## System Settings (sub-project 8)

A separate `system_settings` table stores non-provider configuration:

| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | autoincrement |
| `key` | String(128) | unique (e.g. `risk.max_single_loss`) |
| `value` | JSON | opaque |
| `category` | String(32) | `general` / `risk` / `privacy` / `retention` |
| `updated_at` | DateTime | on update |
| `updated_by` | String(64) | `api` / `cli` / user id |

Admin API: `GET/PUT/DELETE /api/admin/system-settings/{key}` (see `docs/backend/api-contracts.md`).

Seeded rows (4): `general.default_language=zh-CN`, `risk.max_single_loss=5.0`, `privacy.share_ai_prompts=false`, `retention.logs_days=30`.

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` §6
- API contracts: `docs/backend/api-contracts.md`
- Database notes: `docs/database/schema-notes.md`
