---
title: Provider Adapter Foundation — Real API Integration Bedrock
status: draft (awaiting user review)
date: 2026-06-16
authors: claude (brainstorming skill)
supersedes: none (new foundational layer)
related:
  - docs/superpowers/specs/2026-06-15-dashboard-bento-command-grid-design.md
  - docs/production-readiness/* (production-readiness audit context)
---

# Provider Adapter Foundation

## 1. Problem

The backend currently integrates with external products (CCXT, Freqtrade, LLM providers, Telegram, market data feeds, etc.) in ad-hoc, scattered ways:

- `ai_providers.py` covers only three LLM providers (OpenAI / Anthropic / Ollama) with hardcoded handling; remaining LLM candidates (DeepSeek, Qwen, Zhipu, Moonshot, Gemini, Groq, Azure OpenAI) are only `os.environ` checks in `dependency_checker.py`.
- `DataSourceManager` (`data_source_manager.py`) lists 8 categories of data sources (exchange K-line, orderbook, funding, OI, news, whale, on-chain, social), but only `ds-freqtrade` and `ds-redis` are live-tested; the rest are static `DataSourceStatus` instances in `_static_sources()` with no real credentials and no rate-limit awareness.
- `telegram_notifier.py` is a stateless dry-run helper; bot token and chat id are passed as function arguments with no persistence.
- `/tmp/pulsedesk_datasources_state.json` is used for enable/disable persistence — wrong place (tmp), wrong format (no schema, no audit).
- There is no shared concept of "provider": each consumer re-implements its own auth, status, health check, rate-limit reading, and enable/disable.

This blocks:
- Adding new exchanges (OKX, Bybit, Bitget) and DEX venues (gmx, hyperliquid, dydx) — every new venue needs a parallel integration.
- Multi-account / multi-instance providers (e.g. two Binance accounts, multiple OpenAI keys for priority routing).
- Production-grade observability (no consistent health / last-sync / error-message / rate-limit status surface).
- A unified Settings / Data Sources UI in the future (current UI is hard-coded to specific providers).

## 2. Goals

1. **One Provider abstraction** covering 8 categories: `llm` / `cex` / `dex` / `notification` / `market_data` / `onchain` / `social` / `news`.
2. **One config table** (`provider_configs`) with rigorous schema that accommodates future multi-market expansion.
3. **One admin API** (`/api/admin/providers/*`) for CRUD + test + enable/disable + audit.
4. **One lifecycle protocol** (ProviderAdapter): every provider implements `test_connection`, `fetch_rate_limit`, `mask_config`, declares `is_multi_instance` and `config_schema`.
5. **One health pipeline** that reads rate-limit headers at runtime, derives status (active / inactive / error / rate_limited / disabled / unknown), and persists `last_sync_at` / `last_error` / `latency_ms` / `rate_limit_remaining` / `rate_limit_reset_at`.
6. **One background scheduler** (lightweight, native asyncio) that periodically tests enabled+active providers.
7. **Encrypted credentials** at rest, never returned in plaintext from any API response.
8. **Audit log** for every create / update / enable / disable / test / rotate-credentials / delete.
9. **Migrate** all existing code paths (`ai_providers.py`, `DataSourceManager`, `telegram_notifier.py`, `dependency_checker.py`, `llm_service.py`) to use the new foundation in this same round. No parallel layers.

## 3. Non-Goals

- Implementing real DEX on-chain interaction (gmx / hyperliquid / dydx). Stubs only.
- Implementing real OKX / Bybit / Bitget exchange integration. Stubs only.
- WebSocket / SSE push of scheduler results to the iOS app. (Sub-project 7.)
- Real-time WebSocket aggregation across providers. (Sub-project 7.)
- System settings model (general / risk / privacy). (Sub-project 8.)
- iOS visual UI redesign. (Plumbing-only URL changes in this round.)
- Multi-market schema extensions (the design must be *ready* for them, not deliver them).
- Credential rotation endpoint (declared in API surface; implementation deferred to a follow-up).
- Rate-limit circuit-breaker / backoff (only status recording, no automatic blocking).
- Provider config versioning / diff / rollback (audit log only).
- User / RBAC / auth on the admin API (kept open as today).

## 4. Scope Boundaries

- **In scope (this round, "Foundation")**: provider abstraction, single config table, admin API, scheduler, migration of existing LLM / data-source / telegram / dependency-check code, 4 doc files, iOS plumbing URL changes.
- **Out of scope (later sub-projects)**:
  - Sub-project 2: real LLM provider implementations beyond the 3 already-present (OpenAI / Anthropic / Ollama).
  - Sub-project 3: real CEX adapter implementations (OKX, Bybit, Bitget) + Freqtrade normalization.
  - Sub-project 4: real market-data adapter implementations (K-line, orderbook, funding, OI).
  - Sub-project 5: real on-chain / whale / social / news adapter implementations (Glassnode, CryptoQuant, Whale Alert, CryptoCompare, LunarCrush).
  - Sub-project 6: notification providers beyond Telegram (Discord, Email, Webhook).
  - Sub-project 7: real-time WebSocket aggregation.
  - Sub-project 8: system settings model (general / risk / privacy / retention).

This is sub-project 1 of 8 in a planned decomposition. See `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` §11 for the full dependency graph.

## 5. Architecture

### 5.1 Package Layout

All new code under `backend/app/services/providers/`:

```
providers/
├── __init__.py
├── base.py                      # ProviderAdapter Protocol, enums, DTOs
├── registry.py                  # ProviderRegistry singleton; register/get/list
├── runtime.py                   # RateLimitParser, HealthCheckResult, RateLimitInfo
├── crypto.py                    # Thin wrapper over existing CryptoService
├── config_service.py            # ProviderConfigService: DB CRUD, encryption, uniqueness
├── health_service.py            # ProviderHealthService: test, derive status, persist
├── scheduler.py                 # ProviderHealthScheduler: native asyncio periodic tick
└── categories/
    ├── __init__.py              # auto-registers adapters at import
    ├── llm/                     # openai (real), anthropic (real), ollama (real),
    │                            # deepseek/qwen/zhipu/moonshot/gemini/groq/azure_openai (stub)
    ├── cex/                     # binance (real, CCXT), freqtrade (real, FreqtradeClient.ping)
    │                            # okx/bybit/bitget (stub)
    ├── dex/                     # gmx/hyperliquid/dydx (stub)
    ├── notification/            # telegram (real), discord/email/webhook (stub)
    ├── market_data/             # kline/orderbook/funding/oi (stub)
    ├── onchain/                 # glassnode/cryptoquant/whale_alert (stub)
    ├── social/                  # cryptocompare_social/lunarcrush (stub)
    └── news/                    # cryptocompare_news/cryptopanic (stub)
```

### 5.2 Dependency Direction

```
routers/admin/providers.py  ──→  services/providers/{config_service,health_service,registry,scheduler}
                                       │
                                       ├──→ models/provider_config.py  (SQLAlchemy)
                                       ├──→ schemas/provider_config.py  (Pydantic v2 discriminated union)
                                       ├──→ services/crypto_service.py  (existing; reused)
                                       └──→ services/providers/categories/<cat>/<provider>.py
```

### 5.3 Registry

- `ProviderRegistry.register(category, name, adapter_class)` invoked at module import time (side-effect imports in `categories/__init__.py`).
- `registry.get(category, name)` returns a `ProviderAdapter` instance (factory call).
- Singleton held in `app.services.providers.registry.registry`; FastAPI lifespan triggers full import on startup.
- Startup validation: every registered adapter's `is_multi_instance` flag must match its category (LLM=True, all others=False); mismatches raise at startup, not at first request.

### 5.4 Real vs Stub Implementations (this round)

| Category | Provider | Status this round |
|---|---|---|
| llm | openai | Real (migrated from `llm_service.py`) |
| llm | anthropic | Real (migrated) |
| llm | ollama | Real (migrated) |
| llm | deepseek, qwen, zhipu, moonshot, gemini, groq, azure_openai | Stub: `test_connection` returns `not_implemented` |
| cex | binance | Real (CCXT public) |
| cex | freqtrade | Real (FreqtradeClient.ping) |
| cex | okx, bybit, bitget | Stub |
| dex | gmx, hyperliquid, dydx | Stub |
| notification | telegram | Real (migrated from `telegram_notifier.py`) |
| notification | discord, email, webhook | Stub |
| market_data | kline, orderbook, funding, oi | Stub |
| onchain | glassnode, cryptoquant, whale_alert | Stub |
| social | cryptocompare_social, lunarcrush | Stub |
| news | cryptocompare_news, cryptopanic | Stub |

All stubs implement the full `ProviderAdapter` Protocol. They answer `test_connection` with `HealthCheckResult(success=False, error="not_implemented")` and a `status=ERROR` derivation.

## 6. Data Model

### 6.1 Table `provider_configs`

```python
class ProviderConfig(Base):
    __tablename__ = "provider_configs"

    id              = Column(Integer, primary_key=True, autoincrement=True)
    # Identity
    category        = Column(String, nullable=False, index=True)
    provider_name   = Column(String, nullable=False, index=True)
    instance_name   = Column(String, nullable=True)               # required when is_multi_instance
    # Type-specific configuration (non-sensitive)
    config          = Column(JSON, nullable=False, default=dict)  # {base_url, model, timeout_ms, ...}
    # Credentials
    credentials_ct  = Column(Text, nullable=True)                 # Fernet-encrypted JSON
    credentials_fields = Column(JSON, nullable=True)              # ["api_key","api_secret"] for UI
    # Status
    enabled         = Column(Boolean, nullable=False, default=True)   # admin on/off
    is_active       = Column(Boolean, nullable=False, default=False)  # derived: True iff status='active'
    priority        = Column(Integer, nullable=False, default=0)
    status          = Column(String, nullable=False, default="unknown")  # derived enum, see §7.2
    credential_status = Column(String, nullable=False, default="missing")
    last_sync_at    = Column(DateTime, nullable=True)
    last_error      = Column(String, nullable=True)
    latency_ms      = Column(Integer, nullable=True)
    # Rate limit (runtime, from response headers)
    rate_limit_remaining = Column(Integer, nullable=True)
    rate_limit_reset_at  = Column(DateTime, nullable=True)
    created_at      = Column(DateTime, nullable=False, default=_utcnow)
    updated_at      = Column(DateTime, nullable=False, default=_utcnow, onupdate=_utcnow)

    __table_args__ = (
        # Uniqueness is enforced at the service layer. The DB enforces shape:
        # LLM must have instance_name; other categories must NOT.
        CheckConstraint(
            "(category = 'llm' AND instance_name IS NOT NULL) OR "
            "(category != 'llm' AND instance_name IS NULL)",
            name="ck_instance_name_by_category",
        ),
        # Composite index supporting both lookup patterns
        Index("ix_provider_config_cat_name", "category", "provider_name"),
        Index("ix_provider_config_enabled", "enabled"),
    )
```

**Uniqueness enforcement** (service layer, `config_service.py`):
- Before insert/update, query for existing rows matching the appropriate key:
  - LLM: `WHERE category=? AND provider_name=? AND instance_name=?`
  - Other: `WHERE category=? AND provider_name=? AND instance_name IS NULL`
- If found, raise `DuplicateProviderError` → HTTP 409 with `code="duplicate"`.
- The `CheckConstraint` guarantees the search predicate finds only valid candidates.

### 6.2 Pydantic Discriminated Union (`schemas/provider_config.py`)

```python
class ProviderConfigBase(BaseModel):
    category: Literal["llm","cex","dex","notification","market_data","onchain","social","news"]
    provider_name: str
    instance_name: str | None = None
    enabled: bool = True
    priority: int = 0
    config: dict = Field(default_factory=dict)
    credentials: dict | None = None   # plaintext on input; encrypted before storage

class LLMConfig(ProviderConfigBase):
    category: Literal["llm"]
    instance_name: str                   # required
    config: dict
    credentials: dict | None = None      # {api_key}

class CEXConfig(ProviderConfigBase):
    category: Literal["cex"]
    config: dict                         # {base_url, testnet, rate_limit_capacity}
    credentials: dict | None = None      # {api_key, api_secret, passphrase?}

class DeXConfig(ProviderConfigBase):
    category: Literal["dex"]
    config: dict                         # {chain_id, rpc_url, contract_addresses}
    credentials: dict | None = None      # {wallet_address, signature_provider}

class NotificationConfig(ProviderConfigBase):
    category: Literal["notification"]
    config: dict                         # {dry_run, parse_mode}
    credentials: dict | None = None      # {bot_token, chat_id} for telegram

class MarketDataConfig(ProviderConfigBase):
    category: Literal["market_data"]
    config: dict                         # {symbol, timeframe, depth}
    credentials: dict | None = None      # {api_key}

class OnchainConfig(ProviderConfigBase):
    category: Literal["onchain"]
    config: dict                         # {chain, asset, metric}
    credentials: dict | None = None      # {api_key}

class SocialConfig(ProviderConfigBase):
    category: Literal["social"]
    config: dict
    credentials: dict | None = None      # {api_key}

class NewsConfig(ProviderConfigBase):
    category: Literal["news"]
    config: dict
    credentials: dict | None = None      # {api_key}

ProviderConfigPayload = Annotated[
    LLMConfig | CEXConfig | DeXConfig | NotificationConfig
    | MarketDataConfig | OnchainConfig | SocialConfig | NewsConfig,
    Field(discriminator="category"),
]
```

### 6.3 View Model (returned by every read endpoint)

```python
class ProviderConfigView(BaseModel):
    id: int
    category: str
    provider_name: str
    instance_name: str | None
    enabled: bool
    is_active: bool
    priority: int
    status: str
    credential_status: str
    credential_fields: list[str]
    last_sync_at: datetime | None
    last_error: str | None
    latency_ms: int | None
    rate_limit_remaining: int | None
    rate_limit_reset_at: datetime | None
    config: dict                       # masked, non-sensitive
    updated_at: datetime
```

### 6.4 Companion Tables

```python
class ProviderAuditLog(Base):
    __tablename__ = "provider_audit_logs"
    id            = Column(Integer, primary_key=True)
    provider_id   = Column(Integer, ForeignKey("provider_configs.id", ondelete="CASCADE"), nullable=False)
    action        = Column(String, nullable=False)   # create/update/enable/disable/test/rotate/delete
    actor         = Column(String, nullable=True)
    before_hash   = Column(String, nullable=True)    # SHA256-8 of pre-state credential_ct
    after_hash    = Column(String, nullable=True)
    ip            = Column(String, nullable=True)
    created_at    = Column(DateTime, default=_utcnow, nullable=False)
```

`AIUsageLog` (existing) gains nullable `provider_config_id` FK — soft link between usage and the config that produced it.

### 6.5 Encryption

- Existing `CryptoService` (Fernet) is the single encryption boundary.
- `credentials` dict in the request payload → `json.dumps(creds, sort_keys=True)` → `CryptoService.encrypt(...)` → `credentials_ct`.
- `credentials_fields` is a separate plain JSON list of field names the provider's credentials dict contained (so the UI can show "API key configured" without seeing the value).
- `CryptoService` falls back to passthrough when `PULSEDESK_ENCRYPTION_KEY` is unset (dev mode). Read-side handles tampered ciphertext gracefully (returns `INVALID`).

## 7. Provider Adapter Protocol & Health Lifecycle

### 7.1 Protocol (`providers/base.py`)

```python
class ProviderCategory(str, Enum):
    LLM = "llm"; CEX = "cex"; DEX = "dex"; NOTIFICATION = "notification"
    MARKET_DATA = "market_data"; ONCHAIN = "onchain"; SOCIAL = "social"; NEWS = "news"

class ProviderStatus(str, Enum):
    UNKNOWN = "unknown"; ACTIVE = "active"; INACTIVE = "inactive"
    ERROR = "error"; RATE_LIMITED = "rate_limited"; DISABLED = "disabled"

class CredentialStatus(str, Enum):
    MISSING = "missing"; CONFIGURED = "configured"
    EXPIRED = "expired"; INVALID = "invalid"

class HealthCheckResult(BaseModel):
    success: bool
    status: ProviderStatus
    latency_ms: int | None
    error: str | None
    rate_limit: RateLimitInfo | None
    checked_at: datetime

class RateLimitInfo(BaseModel):
    remaining: int | None
    limit: int | None
    reset_at: datetime | None
    retry_after_s: int | None
    source: str                       # e.g. "header:X-MBX-USED-WEIGHT-1M"

class ProviderAdapter(Protocol):
    category: ProviderCategory
    provider_name: str
    is_multi_instance: bool           # LLM=True; all others=False
    config_schema: type[BaseModel]    # Pydantic model for `config` validation

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult: ...
    async def fetch_rate_limit(self, credentials: dict, config: dict) -> RateLimitInfo | None: ...
    def mask_config(self, config: dict) -> dict: ...
```

Adapters do **not** see the ORM row. They receive plaintext credentials and a masked config dict, return a `HealthCheckResult`. This keeps adapters testable in isolation.

### 7.2 Status Derivation

| Input | Derived status |
|---|---|
| `enabled=False` | DISABLED |
| `success=True` and (`rate_limit is None` or `rate_limit.remaining > 0`) | ACTIVE |
| `success=True` and `rate_limit.remaining == 0` | RATE_LIMITED |
| `success=False` and response in (401, 403, expired-token) | INACTIVE |
| `success=False` (other) | ERROR |
| No test in 24+ hours | UNKNOWN |

### 7.3 Rate-Limit Header Parser (`runtime.py`)

Recognized headers (case-insensitive, multi-provider):
- `X-RateLimit-Remaining`, `X-RateLimit-Limit`, `X-RateLimit-Reset`
- `X-MBX-USED-WEIGHT-1M` (Binance)
- `Retry-After` (HTTP standard, seconds or HTTP-date)
- `X-Bapi-Limit-Status`, `X-Bapi-Limit` (Binance public v3)
- `Coinglass-RateLimit-Remaining` (Coinglass-style)

`source` field records which header family produced the value. Unknown providers fall through silently — `rate_limit_remaining` stays `NULL` and the parser does not error.

### 7.4 Error Handling

- Adapter exception → `HealthService` catches → `HealthCheckResult(success=False, error=str(exc)[:200])`, `status=ERROR`.
- Error messages pass through `app.services.privacy_redactor` to mask credential fragments.
- Credential decryption failure → `INVALID` status, `error="credential decryption failed"`. Does not raise.

### 7.5 Scheduler (`scheduler.py`) — Native asyncio, 0 new deps

Two-component split for testability:

```python
class ProviderHealthTickPolicy:
    """Decides which providers to test in a given tick. Pure / unit-testable."""
    def select(self, rows: list[ProviderConfig], now: datetime) -> list[ProviderConfig]: ...

class ProviderHealthScheduler:
    """Runs ticks at fixed interval inside FastAPI lifespan."""
    def __init__(self, interval_s: int = 60, batch_size: int = 10): ...
    async def start(self) -> None: ...   # lifespan entry
    async def stop(self) -> None: ...    # lifespan exit
    async def tick_once(self, db: AsyncSession) -> int: ...  # manual trigger
    async def _loop(self) -> None: ...   # uses asyncio.Event for cancellation
```

Tick policy: order by `last_sync_at ASC NULLS FIRST`, take first `batch_size` rows where `enabled = True`. Stubs are eligible (test_connection will return `not_implemented`); they get `status=ERROR` quickly so the UI shows the truth.

Each tick:
- Uses `asyncio.TaskGroup` (Python 3.11+) to run the batch in structured concurrency; one bad provider does not poison the batch.
- Each provider's test wrapped in `try/except`; logs `WARNING`, continues.

Configuration via `Settings`:
- `provider_health_interval_s: int = 60`
- `provider_health_batch_size: int = 10`
- `provider_health_enabled: bool = True` (set False in dev to avoid noise)

`interval_s=0` disables the loop; the manual `tick_once()` endpoint is always available.

## 8. Admin API Surface

All paths under `/api/admin/providers`. JSON. Errors use standard FastAPI `HTTPException` with `{detail, code}` payload.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/admin/providers/categories` | List all categories with their registered provider names + descriptions |
| GET | `/api/admin/providers?category={c}` | List configs (view model, no plaintext credentials) |
| GET | `/api/admin/providers/{id}` | Single config + its `config_schema` JSON schema hint |
| POST | `/api/admin/providers` | Create (`ProviderConfigPayload` discriminated union) |
| PUT | `/api/admin/providers/{id}` | Update (partial allowed; same payload) |
| DELETE | `/api/admin/providers/{id}` | Delete |
| POST | `/api/admin/providers/{id}/test` | Test using stored credentials |
| POST | `/api/admin/providers/test` | Ephemeral test (no DB write) |
| POST | `/api/admin/providers/{id}/enable` | Set `enabled=True` |
| POST | `/api/admin/providers/{id}/disable` | Set `enabled=False` |
| POST | `/api/admin/providers/{id}/rotate-credentials` | Reserved, returns 501 in this round |
| GET | `/api/admin/providers/{id}/audit-log` | Audit log for a provider |
| GET | `/api/admin/providers/health-summary` | Aggregate counts (active / error / disabled / by category) |
| POST | `/api/admin/providers/health-tick` | Manually trigger one scheduler tick (for "Test all" buttons) |

### 8.1 Critical Invariants

1. **No GET response** includes `credentials_ct` decrypted result, plaintext `credentials`, or any field absent from `ProviderConfigView`.
2. **POST /test** (ephemeral) accepts plaintext credentials but does **not** persist; response is the `HealthCheckResult` only.
3. **POST /providers** encrypts credentials on the way in; sets `credential_status="configured"`; records `credentials_fields` (the dict's top-level keys).
4. **PUT /{id}** replacing credentials overwrites the prior ciphertext; audit log stores `before_hash`/`after_hash` (SHA-256 first 8 hex) of `credentials_ct` — never the plaintext.
5. **enable/disable** writes audit with no credential change.
6. **Unique-constraint violations** surface as HTTP 409 with `code="duplicate"`.
7. **Unknown provider_name** (not in registry) → HTTP 400 with `code="unknown_provider"`.
8. **Rate-limit parser** errors are silent (return `None`); they never raise into the request path.

### 8.2 Response Codes (subset)

| Code | When |
|---|---|
| 200 | Standard success |
| 201 | Create |
| 204 | Delete |
| 400 | `code="unknown_provider"` / `code="invalid_payload"` / `code="missing_credentials"` |
| 404 | `code="not_found"` |
| 409 | `code="duplicate"` |
| 422 | Pydantic validation error |
| 501 | `code="not_implemented"` (e.g. `rotate-credentials` in this round) |

## 9. Migration

This is dev — no production data. We **drop and replace**, no data copy, no compatibility shims.

### 9.1 Backend Drops & Creates

| Action | Target |
|---|---|
| DROP TABLE | `ai_provider_configs` (CASCADE) |
| DROP FILE | `/tmp/pulsedesk_datasources_state.json` |
| DELETE FILE | `backend/app/services/data_source_manager.py` |
| DELETE FILE | `backend/app/routers/data_source_bff.py` |
| REMOVE CLASS | `AIProviderConfig` from `backend/app/models/ai_provider.py` (keep `AIUsageLog` in same file with new nullable `provider_config_id` FK) |
| CREATE TABLE | `provider_configs` |
| CREATE TABLE | `provider_audit_logs` |
| ADD COLUMN | `AIUsageLog.provider_config_id` (nullable, FK to `provider_configs.id` ON DELETE SET NULL) |

Single Alembic migration `2026_06_16_xxxx_provider_foundation.py` does the table swap.

### 9.2 Backend Code Rewrites

| Old | New |
|---|---|
| `app/routers/ai_providers.py` (LLM CRUD/test/usage/models_status/models_runtime/routing/privacy) | Split:<br>- LLM CRUD/test/usage → `app/routers/admin/providers.py`<br>- ML model status (FinBERT/Chronos/TimesFM/SHAP) stays in `app/routers/ai_providers.py` at `/api/ai/models/*` (these are ML models, not providers)<br>- Routing rules / privacy rules stay at `/api/ai/routing-rules` and `/api/ai/privacy-rules` |
| `app/services/llm_service.py` (`OpenAIProvider`/`AnthropicProvider`/`OllamaProvider` classes) | Migrate to `app/services/providers/categories/llm/{openai,anthropic,ollama}.py`; `LLMService` becomes a priority-based selector using `ProviderRegistry` |
| `app/services/telegram_notifier.py` | `app/services/providers/categories/notification/telegram.py` (full adapter); keep a thin `send_telegram_notification` wrapper that pulls creds from `provider_configs` |
| `app/services/dependency_checker.py` | DB-first: read `provider_configs` (LLM category and any other enabled+configured); env vars as fallback for "DB not yet populated" dev path |
| `app/routers/notifications.py` `/telegram/dry-run` | Removed; users test via `POST /api/admin/providers/test` with `category=notification, provider_name=telegram` |

### 9.3 iOS Plumbing-Only Changes

Visual UI (DataSourcesView / ExchangeSettingsView / McpServerSettingsView / NotificationSettingsView / AIProvidersView / Settings tabs) is **not** touched. Only the API call layer:

| File | Change |
|---|---|
| `macos-app/AlphaLoop/Services/APIAIProviders.swift` | Point at `/api/admin/providers?category=llm` and `/api/admin/providers/{id}/test`. Update Codable structs to match the new view model. |
| `macos-app/AlphaLoop/Services/APIDataSources.swift` | Point at `/api/admin/providers`. Map view-model fields. |
| `macos-app/AlphaLoop/Services/APINotifications.swift` | Replace the telegram dry-run call with `POST /api/admin/providers/test` using the telegram provider. |
| `macos-app/AlphaLoop/State/SettingsState.swift` | `loadFromBackend()` continues to call `/auth/settings` (unchanged). |

No new visual screens, no design-system changes, no layout reflow.

### 9.4 iOS Compatibility After Drop

After the backend drops `/api/ai/providers` and `/api/data-sources`, the iOS app only works against the new backend in the same release. The previous iOS build against the previous backend will break. Acceptable for a dev-phase project.

## 10. Documentation (4 files, all new in this repo)

| File | Contents |
|---|---|
| `docs/integrations/api-audit.md` | Per-provider research entries: official docs URL, auth method, key endpoints used, rate-limit headers, sandbox/test endpoints. This round covers LLM (3 real) + Notification (telegram) + Exchange (binance, freqtrade) in full; remaining categories list stub providers with their official docs URLs only. |
| `docs/settings/configuration-model.md` | The `provider_configs` table, Pydantic discriminated union, view model, single-instance vs multi-instance rule, encryption flow, audit log. |
| `docs/backend/api-contracts.md` | All `/api/admin/providers/*` endpoints: request/response schemas, status codes, invariants (esp. "no plaintext credentials in any response"). |
| `docs/database/schema-notes.md` | ER diagram, table definitions, indices, unique constraints, check constraints, FK relationships to `AIUsageLog`, alembic history entry. |

## 11. Implementation Order (5 PRs, each independently mergeable and revertable)

```
PR1 — Bedrock
  - providers/{base,registry,runtime,crypto,rate_limit_parser,config_service,health_service,scheduler}.py
  - models/provider_config.py + schemas/provider_config.py
  - tests/providers/* (unit)
  - Alembic migration: drop ai_provider_configs, create provider_configs + provider_audit_logs
  - settings.py additions (provider_health_* keys)

PR2 — Adapters (6 real + ~12 stub)
  - providers/categories/** with auto-registration in __init__.py
  - tests/providers/categories/*

PR3 — Router & migration
  - routers/admin/providers.py
  - drop routers/ai_providers.py LLM section; keep ML model status + routing rules + privacy rules
  - drop routers/data_source_bff.py
  - drop services/data_source_manager.py
  - rewrite services/llm_service.py (priority selector)
  - rewrite services/telegram_notifier.py (thin wrapper)
  - rewrite services/dependency_checker.py (DB-first)
  - tests/integration/test_admin_providers_api.py
  - iOS plumbing: 4 API*.swift URL updates

PR4 — Docs
  - docs/integrations/api-audit.md
  - docs/settings/configuration-model.md
  - docs/backend/api-contracts.md
  - docs/database/schema-notes.md

PR5 — Wrap-up
  - Run full pytest, coverage ≥ 30%
  - Run swift build, confirm iOS compiles
  - Update CLAUDE.md "Backend Architecture" section
  - Update README.md
  - Spec self-review
```

## 12. Testing Strategy

### 12.1 Unit Tests (`backend/tests/providers/`)

| File | Covers |
|---|---|
| `test_base.py` | Protocol compile, DTO serialization |
| `test_registry.py` | register/get/list, multi-instance flag mismatch raises, duplicate registration raises |
| `test_config_service.py` | CRUD, encryption round-trip, unique constraints, **no plaintext leak in view model** |
| `test_health_service.py` | test_connection orchestration, status derivation table, rate_limit capture |
| `test_rate_limit_parser.py` | All known header families; unknown providers silent |
| `test_scheduler.py` | `ProviderHealthTickPolicy.select()` table; `tick_once` happy / with one bad provider / with no enabled rows; `interval_s=0` disables loop |
| `test_crypto_integration.py` | Encrypt/decrypt round-trip; passthrough mode; tampered ciphertext → INVALID |
| `categories/test_*.py` (per real provider) | happy / 401 / 429 / network error / timeout / malformed response |

### 12.2 Integration Tests (`backend/tests/integration/test_admin_providers_api.py`)

Uses SQLite in-memory + real FastAPI `TestClient`:
- `POST /api/admin/providers` with credentials → raw-SQL inspection of `credentials_ct` shows ciphertext (not plaintext); no plaintext in any response field.
- `GET /api/admin/providers/{id}` **never** includes plaintext key/secret.
- `POST /api/admin/providers/test` (ephemeral) does **not** write to DB.
- Duplicate `(category=cex, provider_name=binance)` → 409.
- Duplicate `(category=llm, provider_name=openai, instance_name=dev)` → 409.
- LLM without `instance_name` → 400.
- Audit log row appears for each create/update/enable/disable/test/rotate/delete action.
- `POST /enable` and `/disable` toggle `enabled` field.
- `POST /providers` with `category=foo` (not in registry) → 400.
- `POST /{id}/rotate-credentials` → 501.

### 12.3 Manual End-to-End (no automation this round)

1. iOS app launches → DataSourcesView pulls from `/api/admin/providers` → shows each provider with `status=unknown` and `credential_status=missing` until configured.
2. iOS Settings → API → fill OpenAI key → save → DataSourcesView's openai card transitions to `status=active` on next scheduler tick (≤ 60s).
3. Tap "Test Connection" on a card → immediate result.
4. Disable a provider (Settings) → card turns `disabled`; scheduler skips it next tick.
5. Trigger "Test All" → all enabled providers test in batch; UI updates.

### 12.4 Mock Strategy

- External HTTP: `aioresponses` or `respx`.
- DB: `sqlite:///:memory:` + `Base.metadata.create_all`.
- Scheduler: `monkeypatch` `asyncio.sleep`; manual `asyncio.Event` for cancellation.
- iOS: no new tests.

## 13. Acceptance Criteria

| Item | Standard |
|---|---|
| pytest | All green, coverage ≥ 30% (CI gate) |
| Real provider implementations | ≥ 6 (openai, anthropic, ollama, telegram, binance, freqtrade) |
| Stub provider implementations | ≥ 12 (every other provider in every category) |
| Unique constraints | Integration test covers single-instance and LLM multi-instance paths |
| Plaintext leak | Integration test asserts no plaintext in any GET response and that `credentials_ct` is encrypted in DB |
| Audit log coverage | create / update / enable / disable / test / rotate / delete all logged |
| Scheduler | `interval_s=0` disable test passes; `interval_s=60` tick policy test passes |
| iOS compile | `swift build` succeeds; URL strings updated in 3 API files |
| Documentation | 4 files, each ≥ 200 lines, with ER diagram / endpoint table / schema field table |

## 14. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| DROP `ai_provider_configs` is irreversible | Dev phase, no production data; accept |
| iOS app loses old endpoints | Same-release update; acceptable in dev |
| Scheduler slow on startup | `tick_once` is lazy (runs after a 1s grace period post-lifespan-entered); does not block readiness |
| `LLMService` refactor breaks existing tests | Run full pytest after PR2; LLMService is only consumer of the new LLM adapters |
| Stub providers flood health-summary with ERROR | Health-summary endpoint documents the count of `status=ERROR` rows; users can see at a glance "6 stubs not implemented yet" |
| Pydantic discriminated union breaks under future schema drift | Discriminator name (`category`) is part of the contract; documented as load-bearing in `docs/settings/configuration-model.md` |

## 15. Open Questions Deferred to Follow-up

- Whether `provider_audit_logs` should be partitioned by month (volume not yet known; not a concern at expected dev scale).
- Whether the iOS app should poll `/api/admin/providers/health-summary` for live updates, or receive WebSocket pushes (decided for sub-project 7).
- Whether `rotate-credentials` should be implemented as a first-class endpoint or a special case of `PUT /{id}` (kept as separate endpoint placeholder for now; spec for behavior deferred).

## 16. Cross-references

- Sub-project 2 (LLM provider expansions): depends on this spec, will replace stubs at `app/services/providers/categories/llm/`.
- Sub-project 3 (Exchange normalization): reuses `app/services/providers/categories/cex/freqtrade.py` adapter and the CCXT-based `binance.py`.
- Sub-project 7 (WebSocket real-time): will add a publisher to `ProviderHealthScheduler.tick_once` to broadcast results.
- Sub-project 8 (System settings model): will add a parallel `system_settings` table; not part of `provider_configs`.

---

**End of spec.**
