---
title: Sub-project 2 — LLM Provider Real Implementations (7 stubs → real)
status: approved
date: 2026-06-16
authors: claude (brainstorming skill)
supersedes: docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md (only the LLM-section content of api-audit.md)
related:
  - docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md
  - docs/superpowers/plans/2026-06-16-provider-adapter-foundation.md
  - docs/integrations/api-audit.md
---

# Sub-project 2 — LLM Provider Real Implementations

## 1. Problem

After sub-project 1 (Provider Adapter Foundation), 7 LLM providers are
registered as **stubs** that return `HealthCheckResult(success=False, error="not_implemented")`:

- DeepSeek, Qwen, Zhipu, Moonshot, Gemini, Groq, Azure OpenAI

The framework (ProviderAdapter Protocol, ProviderRegistry, ProviderConfigService,
ProviderHealthService, scheduler, admin API) is fully built and tested. This
sub-project implements real `test_connection` for each of the 7 stubs by
adapting to each provider's official API, following the same pattern as
existing OpenAI / Anthropic / Ollama adapters.

## 2. Goals

1. Implement 7 real LLM adapters using each provider's official API.
2. Use Bearer auth for 6 providers and `api-key` header for Azure OpenAI.
3. Use GET-on-models (or minimal-cost) endpoints for `test_connection` so
   health checks don't consume tokens.
4. Surface `Retry-After` and (for Groq) the `x-ratelimit-*` family via the
   existing `RateLimitParser`.
5. Update `docs/integrations/api-audit.md` with full LLM section (replace
   the 7 "stub" entries from sub-project 1).
6. No new dependencies, no schema changes, no migration. Pure code addition.

## 3. Non-Goals

- Implementing `chat()` / completion logic. The adapter exposes only
  `test_connection` and `fetch_rate_limit` (per ProviderAdapter Protocol).
  Future sub-projects may add an inference dispatcher.
- Adding retry / circuit-breaker policies. Out of scope; spec §15 defers
  to follow-up.
- WebSocket / streaming. Out of scope.
- Region-specific base URL detection (Qwen China vs intl, Moonshot
  China vs global). The config schema exposes `base_url`; users set it
  to the region they use.

## 4. Provider-Specific Reference

### 4.1 DeepSeekProvider

- **Auth:** `Authorization: Bearer <key>` header
- **Base URL:** `https://api.deepseek.com/v1` (configurable)
- **Health endpoint:** `GET /models` (OpenAI-compatible, no token cost)
- **Rate-limit headers:** Not consistently documented; fall back to `Retry-After`
- **Error codes:** 401 (auth fail) → INACTIVE; 429 → RATE_LIMITED; 5xx → ERROR
- **Config schema:** `DeepSeekConfig { base_url, model, timeout_s }` (default model: `deepseek-chat`)

### 4.2 QwenProvider (Alibaba DashScope, compatible-mode)

- **Auth:** `Authorization: Bearer <key>` header
- **Base URL:** `https://dashscope.aliyuncs.com/compatible-mode/v1` (configurable; China or intl)
- **Health endpoint:** `GET /models` (OpenAI-compatible mode)
- **Rate-limit headers:** Not documented in evidence; fall back to `Retry-After`
- **Error codes:** Same as DeepSeek
- **Config schema:** `QwenConfig { base_url, model, timeout_s }` (default model: `qwen-plus`)

### 4.3 ZhipuProvider (智谱 GLM)

- **Auth:** `Authorization: Bearer <key>` header
- **Base URL:** `https://open.bigmodel.cn/api/paas/v4` (configurable)
- **Health endpoint:** `GET /models` (OpenAI-compatible)
- **Rate-limit headers:** Not documented; fall back to `Retry-After`
- **Error codes:** Same as DeepSeek
- **Config schema:** `ZhipuConfig { base_url, model, timeout_s }` (default model: `glm-4`)

### 4.4 MoonshotProvider (月之暗面 Kimi)

- **Auth:** `Authorization: Bearer <key>` header
- **Base URL:** `https://api.moonshot.cn/v1` (configurable; `.cn` for China, `.ai` for global)
- **Health endpoint:** `GET /models` (OpenAI-compatible)
- **Rate-limit headers:** Not documented; fall back to `Retry-After`
- **Error codes:** Same as DeepSeek
- **Config schema:** `MoonshotConfig { base_url, model, timeout_s }` (default model: `moonshot-v1-8k`)

### 4.5 GeminiProvider (Google AI Studio)

- **Auth:** `?key=<api_key>` query parameter (NOT a Bearer header)
- **Base URL:** `https://generativelanguage.googleapis.com` (configurable)
- **Health endpoint:** `GET /v1beta/models?key=<key>&pageSize=1` (list models, no token cost)
- **Rate-limit headers:** Not documented in standard response; 429 on quota exceeded
- **Error codes:** 400 (invalid arg) → ERROR; 401/403 → INACTIVE; 404 → ERROR; 429 → RATE_LIMITED; 503/504 → ERROR
- **Config schema:** `GeminiConfig { base_url, model, timeout_s }` (default model: `gemini-1.5-flash`)

### 4.6 GroqProvider

- **Auth:** `Authorization: Bearer <key>` header
- **Base URL:** `https://api.groq.com/openai/v1` (configurable)
- **Health endpoint:** `GET /models` (OpenAI-compatible)
- **Rate-limit headers (well-documented):** `x-ratelimit-limit-requests`, `x-ratelimit-remaining-requests`, `x-ratelimit-reset-requests`, `x-ratelimit-limit-tokens`, `x-ratelimit-remaining-tokens`, `x-ratelimit-reset-tokens`, `Retry-After` (seconds)
- **Error codes:** 400 → ERROR; 401 → INACTIVE; 429 → RATE_LIMITED; 5xx → ERROR
- **Config schema:** `GroqConfig { base_url, model, timeout_s }` (default model: `llama-3.1-70b-versatile`)

### 4.7 AzureOpenAIProvider

This provider is structurally different from the others:
- Per-deployment URL (no fixed base URL)
- `api-key: <key>` header (NOT Bearer)
- `api-version` query parameter
- Path includes deployment name

- **Auth:** `api-key: <key>` header
- **Base URL:** per-deployment, e.g. `https://{resource}.openai.azure.com/openai/deployments/{deployment}` (set via `endpoint` config field)
- **Health endpoint:** `POST /chat/completions?api-version=2024-08-01-preview` with `{"messages":[{"role":"user","content":"ping"}],"max_tokens":1}` (minimal cost; 1 token)
  - Note: This is the **only POST** health check in the project. All others are GET.
  - Rationale: Azure OpenAI does not expose a models-list endpoint by default; chat completions is the standard probe.
- **Rate-limit headers:** Azure returns `Retry-After` on 429; other rate-limit headers not standardized
- **Error codes:** 401 → INACTIVE; 404 (deployment not found) → ERROR; 429 → RATE_LIMITED; 5xx → ERROR
- **Config schema:** `AzureOpenAIConfig { endpoint, deployment, api_version, model, timeout_s }`
- **Credentials:** `api_key` (named explicitly to disambiguate from Bearer key)

## 5. Architecture

### 5.1 File Layout

All new code under `backend/app/services/providers/categories/llm/`:

```
categories/llm/
├── __init__.py              # updated: register 7 new providers
├── openai.py                # existing
├── anthropic.py             # existing
├── ollama.py                # existing
├── deepseek.py             # NEW
├── qwen.py                  # NEW
├── zhipu.py                 # NEW
├── moonshot.py              # NEW
├── gemini.py                # NEW
├── groq.py                  # NEW
└── azure_openai.py          # NEW
```

Test files (one per adapter):

```
tests/providers/categories/llm/
├── test_deepseek.py
├── test_qwen.py
├── test_zhipu.py
├── test_moonshot.py
├── test_gemini.py
├── test_groq.py
└── test_azure_openai.py
```

### 5.2 Adapter Pattern (per provider)

Each adapter follows the same shape as `OpenAIProvider` (Task 2.1):

```python
class XxxConfig(BaseModel):
    base_url: str = Field(default=...)
    model: str = Field(default=...)
    timeout_s: float = Field(default=10.0)
    # AzureOpenAIConfig adds:
    # endpoint: str, deployment: str, api_version: str

class XxxProvider:
    category = ProviderCategory.LLM
    provider_name = "..."
    is_multi_instance = True
    config_schema = XxxConfig

    async def test_connection(self, credentials, config) -> HealthCheckResult: ...
    async def fetch_rate_limit(self, credentials, config) -> RateLimitInfo | None: ...
    def mask_config(self, config) -> dict: ...
```

### 5.3 Test Pattern (per provider)

Each test file has 3-4 tests (mirroring `test_llm_openai.py`):
- `test_200_returns_active` — mocks aiohttp returning 200
- `test_401_returns_inactive` — mocks 401
- `test_missing_credentials_returns_error` — empty creds
- (Gemini adds) `test_429_returns_rate_limited` — verifies status derivation
- (Groq adds) `test_rate_limit_headers_parsed` — verifies `x-ratelimit-*` parsing
- (AzureOpenAI adds) `test_uses_api_key_header_not_bearer` — verifies header shape
- (AzureOpenAI adds) `test_post_endpoint_with_api_version_query` — verifies POST + query

### 5.4 Registration

Update `categories/llm/__init__.py` to import and register the 7 new classes (in addition to the existing 3). After this change, the registry contains 10 LLM providers.

## 6. Data Model

**No schema changes.** All existing tables (`provider_configs`, `provider_audit_logs`, `AIUsageLog`) are reused.

The only new data is the `config` JSON dict for each provider, which has a provider-specific shape (see §4 schemas). This is validated by Pydantic at write time and stored as JSON.

## 7. Status Mapping (unchanged from sub-project 1)

| Condition | Status |
|---|---|
| 200 OK | active |
| 401/403 Unauthorized | inactive |
| 429 Too Many Requests | rate_limited |
| 5xx Server Error | error |
| timeout / connection error | error |
| missing required credential | error |

## 8. Migration

**No migration.** Pure code addition. Existing `provider_configs` rows for any of these 7 providers are stubs; admins can now save real credentials and they will be tested against real endpoints.

## 9. Documentation Updates

- **`docs/integrations/api-audit.md`** — replace the "DeepSeek / Qwen / ... / Azure OpenAI (stubs)" section with full per-provider entries (mirroring the OpenAI / Anthropic / Ollama format). Each entry: provider class, official docs URL, auth, used endpoint, rate-limit headers, config schema, test env.

## 10. Testing Strategy

### Unit tests (`tests/providers/categories/llm/test_*.py`)

Per provider, 3-4 mocked tests:
- happy path (200 → ACTIVE)
- 401 (auth fail → INACTIVE)
- missing credential (error)
- provider-specific edge (e.g., Groq rate-limit header parsing; Azure API-key header shape)

### Integration tests

**No new integration tests.** The existing `tests/integration/test_admin_providers_api.py` already covers the create / encrypt / uniqueness / audit flow. The 7 new providers are registered via the same machinery.

### Manual smoke test

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.services.providers.categories import register_all
register_all()
from app.services.providers.registry import registry
print('LLM:', sorted(registry.list_providers('llm')))
"
```

Expected: `['anthropic', 'azure_openai', 'deepseek', 'gemini', 'groq', 'moonshot', 'ollama', 'openai', 'qwen', 'zhipu']` (10 providers).

## 11. Implementation Order

1. Implement 7 providers (one PR per provider OR one PR for all 7 — single PR preferred for atomicity).
2. Tests (one file per provider, 3-4 tests each, ~25 tests total).
3. Update `categories/llm/__init__.py` to register the 7 new classes.
4. Update `docs/integrations/api-audit.md` (replace stub entries).
5. Commit.

## 12. Acceptance Criteria

- 7 new adapter files exist; 7 new test files exist
- All 25+ new tests pass
- Existing 39 unit tests still pass (no regression)
- `registry.list_providers('llm')` returns 10 providers
- `swift build` still passes
- `docs/integrations/api-audit.md` LLM section updated; each new provider has full entry
- No new dependencies added to `requirements.txt`
- No schema changes; no migration
- The 7 providers can be created via `POST /api/admin/providers` and tested via `POST /api/admin/providers/{id}/test` (verified manually in dev)

## 13. Risks

| Risk | Mitigation |
|---|---|
| Health endpoint chosen here may not work for all 7 providers | Use OpenAI-compatible `GET /models` for the 6 Bearer providers (well-established pattern); for Azure use the documented minimal-completion probe |
| Rate-limit headers inconsistent across providers | Existing `RateLimitParser` already silently falls through; no harm |
| Azure OpenAI requires `api-key` header, not Bearer | Adapter builds request with `api-key` header; documented in spec |
| Gemini uses `?key=` query, not Bearer | Adapter builds URL with `?key=`; documented |
| Real implementation may differ from docs in edge cases (e.g., unexpected 200-with-error-JSON) | Tests use `resp.status == 200` check first; if response body parsing reveals error, can be refined later in a follow-up |
| Existing `LLMService` doesn't dispatch to these providers (only OpenAI/Anthropic/Ollama were used) | Out of scope; spec §15 defers inference dispatcher. The adapters are testable via the framework even without an inference dispatcher. |

## 14. Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` (sub-project 1)
- Plan: `docs/superpowers/plans/2026-06-16-provider-adapter-foundation.md`
- API contracts: `docs/backend/api-contracts.md` (unchanged; this sub-project adds adapters that the existing `/api/admin/providers/{id}/test` endpoint will use)
- API audit: `docs/integrations/api-audit.md` (LLM section to be updated)
