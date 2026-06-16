# API Contracts — Provider Admin API

The Provider Admin API is served under `/api/admin/providers/*`. It
exposes CRUD + test + enable/disable + audit operations on the
`provider_configs` table.

This document specifies every endpoint, the request/response schema,
the error codes, and the load-bearing invariants.

## Conventions

- All endpoints return JSON.
- All errors use FastAPI's `HTTPException` with `{"detail": {"code": "...", "message": "..."}, "status_code": N}`.
- All `provider_id` path parameters are integers referring to `provider_configs.id`.
- `instance_name` is required for `llm` and **must be NULL** for all other categories (enforced at the DB level).

## Critical Invariants

These rules apply to **every** endpoint in this surface:

1. **No GET response** includes `credentials_ct` (decrypted or raw), plaintext `credentials`, or any field absent from `ProviderConfigView`.
2. **POST /test** (ephemeral) accepts plaintext credentials but does **not** persist.
3. **POST /providers** encrypts credentials on the way in; sets `credential_status="configured"`; records `credentials_fields`.
4. **PUT /{id}** replacing credentials overwrites the prior ciphertext; audit log stores `before_hash`/`after_hash` (SHA-256 first 8 hex) — never plaintext.
5. **enable/disable** writes audit with no credential change.
6. **Unique-constraint violations** surface as HTTP 409 with `code="duplicate"`.
7. **Unknown provider_name** (not in registry) → HTTP 400 with `code="unknown_provider"`.
8. **Rate-limit parser** errors are silent (return `None`); they never raise into the request path.

## Endpoints

### `GET /api/admin/providers/categories`

Returns all 8 categories with their registered provider names.

**Response (200):**
```json
{
  "categories": {
    "llm": [{"name": "openai", "is_multi_instance": true}, ...],
    "cex": [{"name": "binance", "is_multi_instance": false}, ...],
    ...
  }
}
```

### `GET /api/admin/providers?category={category}`

Lists all configs (or filtered by category). Returns `[ProviderConfigView]`.

**Response (200):** list of `ProviderConfigView` objects (see
`docs/settings/configuration-model.md`).

### `GET /api/admin/providers/{id}`

Single config.

**Response (200):** `ProviderConfigView`.
**Errors:** 404 `not_found`.

### `POST /api/admin/providers`

Create a new config. Body is `ProviderConfigPayload` (Pydantic
discriminated union by `category`).

**Response (201):** `ProviderConfigView`.
**Errors:**
- 400 `invalid_payload` (Pydantic validation failed)
- 400 `unknown_provider` (provider_name not in registry for category)
- 409 `duplicate` (unique constraint violated)

### `PUT /api/admin/providers/{id}`

Update an existing config. Body is a partial dict (any subset of
`config`, `credentials`, `enabled`, `priority`). `category` and
`provider_name` are taken from the row, not the body.

**Response (200):** updated `ProviderConfigView`.
**Errors:**
- 400 `invalid_payload`
- 404 `not_found`
- 409 `duplicate` (only if a different row would now collide; the row's own update never collides)

### `DELETE /api/admin/providers/{id}`

Hard delete. Cascades to `provider_audit_logs` (FK ON DELETE CASCADE).
Sets `ai_usage_logs.provider_config_id` to NULL.

**Response:** 204 No Content.
**Errors:** 404 `not_found`.

### `POST /api/admin/providers/{id}/test`

Run a connection test using the row's stored credentials. Writes the
result back to the row (status, latency, last_error, rate_limit_remaining).

**Response (200):** `HealthCheckResultSchema`:
```json
{
  "success": true,
  "status": "active",
  "latency_ms": 42,
  "error": null,
  "rate_limit": {"remaining": 5900, "limit": 6000, "reset_at": null, "retry_after_s": null, "source": "header:x-mbx-used-weight-1m"},
  "checked_at": "2026-06-16T12:00:00Z"
}
```

**Errors:** 404 `not_found`.

### `POST /api/admin/providers/test`

Ephemeral test. Body is `ProviderTestRequest` with plaintext credentials.
**Does not** write to the DB.

**Response (200):** `HealthCheckResultSchema` (same as above).
**Errors:** none (the request always returns 200 with a result, even on failure).

### `POST /api/admin/providers/{id}/enable`

Set `enabled=True`. Updates `status` (no longer "disabled").

**Response (200):** `ProviderConfigView`.
**Errors:** 404 `not_found`.

### `POST /api/admin/providers/{id}/disable`

Set `enabled=False`. Sets `status="disabled"`. The scheduler skips this row.

**Response (200):** `ProviderConfigView`.
**Errors:** 404 `not_found`.

### `POST /api/admin/providers/{id}/rotate-credentials`

**Reserved.** Returns 501 in this round. Will replace stored credentials
with a new value (e.g. for OAuth refresh flows). Implementation deferred.

**Response:** 501 `not_implemented`.

### `GET /api/admin/providers/{id}/audit-log?limit=50`

Lists the most recent N audit log entries for the provider, newest first.

**Response (200):**
```json
[
  {
    "id": 17,
    "action": "update",
    "actor": "api",
    "before_hash": "ab12cd34",
    "after_hash": "ef56gh78",
    "ip": "127.0.0.1",
    "created_at": "2026-06-16T12:00:00Z"
  },
  ...
]
```

### `GET /api/admin/providers/health-summary`

Aggregate counts across all providers.

**Response (200):**
```json
{
  "by_category": {"llm": 3, "cex": 2, "notification": 1, ...},
  "total_active": 4,
  "total_error": 2,
  "total_disabled": 0,
  "total_configured": 5,
  "total": 6,
  "checked_at": "2026-06-16T12:00:00Z"
}
```

### `POST /api/admin/providers/health-tick`

Manually trigger one scheduler tick. Useful for the "Test All" UI button.

**Response (200):** `{"tested": 5}` (number of providers tested).

## End-to-End Flow Examples

### Create an LLM provider

```bash
curl -X POST /api/admin/providers \
  -H "Content-Type: application/json" \
  -d '{
    "category": "llm",
    "provider_name": "openai",
    "instance_name": "default",
    "config": {"model": "gpt-4o"},
    "credentials": {"api_key": "sk-..."}
  }'
```

Response (201):
```json
{
  "id": 1,
  "category": "llm",
  "provider_name": "openai",
  "instance_name": "default",
  "enabled": true,
  "is_active": false,
  "priority": 0,
  "status": "unknown",
  "credential_status": "configured",
  "credentials_fields": ["api_key"],
  "last_sync_at": null,
  "last_error": null,
  "latency_ms": null,
  "rate_limit_remaining": null,
  "rate_limit_reset_at": null,
  "config": {"model": "gpt-4o"},
  "updated_at": "2026-06-16T12:00:00Z"
}
```

### Test a provider

```bash
curl -X POST /api/admin/providers/1/test
```

Response (200):
```json
{
  "success": true,
  "status": "active",
  "latency_ms": 312,
  "error": null,
  "rate_limit": {"remaining": 5900, "limit": 6000, "reset_at": null, "retry_after_s": null, "source": "header:x-ratelimit-remaining"},
  "checked_at": "2026-06-16T12:05:00Z"
}
```

### Ephemeral test (no DB write)

```bash
curl -X POST /api/admin/providers/test \
  -H "Content-Type: application/json" \
  -d '{
    "category": "cex",
    "provider_name": "binance",
    "config": {},
    "credentials": {"api_key": "test", "api_secret": "test"}
  }'
```

Response (200): `HealthCheckResultSchema` (same structure as above).
The row is never created; the response reflects only what the adapter
returned at call time.

### Disable a provider

```bash
curl -X POST /api/admin/providers/1/disable
```

Response (200):
```json
{
  "id": 1,
  "enabled": false,
  "status": "disabled",
  ...
}
```

### View audit trail

```bash
curl /api/admin/providers/1/audit-log?limit=5
```

Response (200):
```json
[
  {"id": 1, "action": "create", "actor": "api", "before_hash": null, "after_hash": "a1b2c3d4", "ip": "127.0.0.1", "created_at": "..."},
  {"id": 2, "action": "test", "actor": "api", "before_hash": null, "after_hash": null, "ip": "127.0.0.1", "created_at": "..."},
  {"id": 3, "action": "disable", "actor": "api", "before_hash": null, "after_hash": null, "ip": "127.0.0.1", "created_at": "..."}
]
```

## Error Code Reference

| Code | HTTP | When |
|---|---|---|
| `not_found` | 404 | row id does not exist |
| `duplicate` | 409 | unique-constraint violation |
| `unknown_provider` | 400 | provider_name not in registry |
| `invalid_payload` | 400 | Pydantic validation failed |
| `not_implemented` | 501 | endpoint reserved but not yet built |

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` §8
- Configuration model: `docs/settings/configuration-model.md`
- API audit (per-provider details): `docs/integrations/api-audit.md`

## System Settings

All paths under `/api/admin/system-settings/*`. The new `system_settings` table stores non-provider configuration (general/risk/privacy/retention).

### `GET /api/admin/system-settings?category={category}`

List all settings (or filtered by `general`/`risk`/`privacy`/`retention`).

**Response (200):** list of `SystemSettingView`:
```json
[
  {"id": 1, "key": "general.default_language", "value": {"value": "zh-CN"}, "category": "general", "updated_at": "2026-06-17T12:00:00Z", "updated_by": "system"},
  ...
]
```

### `GET /api/admin/system-settings/{key}`

Get a single setting. `{key:path}` matches dotted keys like `risk.max_single_loss`.

**Response (200):** `SystemSettingView`.
**Errors:** 404 `not_found`.

### `PUT /api/admin/system-settings/{key}`

Create or update. Body: `{"value": {...}, "category": "...", "updated_by": "alice"}`.

**Response (200):** updated `SystemSettingView`.

### `DELETE /api/admin/system-settings/{key}`

Hard delete.

**Response:** 204 No Content.
**Errors:** 404 `not_found`.

## Real-time WebSocket (sub-project 7)

All WebSocket connections are unauthenticated for now (admin auth deferred to sub-project 9+).

### `WS /api/ws/provider-health`

Real-time stream of provider health updates. Server pushes JSON frames.

**Initial frame (sent on connect):**
```json
{
  "type": "snapshot",
  "ts": "2026-06-17T12:00:00Z",
  "providers": [
    {"id": 1, "key": "...", "value": {...}, "category": "...", ...}
  ]
}
```

**Update frames (when a provider's status changes):**
```json
{
  "type": "update",
  "ts": "2026-06-17T12:01:00Z",
  "provider_id": 1,
  "status": "active",
  "latency_ms": 42,
  "error": null
}
```

**Heartbeat (every 30s to keep connection alive):**
```json
{"type": "heartbeat", "ts": "..."}
```

Backed by `app.services.providers.realtime.health_broadcaster` (in-memory pub/sub fed by `ProviderHealthService.test_from_row`).

### `GET /api/providers/ticker/{symbol}` (planned, sub-project 7.5)

Returns the latest cached ticker data from `app.services.providers.realtime.ticker_cache`. Read by `CCXT Binance watch_ticker` background task. Default symbols: `BTC/USDT`.

**Response (200):** `{"last": 50000.0, "bid": ..., "ask": ..., "volume": ..., "ts": ...}`
**Errors:** 404 `not_found` (no recent data; TTL 60s).
