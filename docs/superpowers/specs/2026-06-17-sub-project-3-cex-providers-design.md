---
title: Sub-project 3 — CEX Provider Real Implementations (OKX/Bybit/Bitget)
status: approved
date: 2026-06-17
authors: claude (brainstorming skill)
supersedes: docs/integrations/api-audit.md (only the CEX stub section)
related:
  - docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md
  - docs/superpowers/specs/2026-06-16-sub-project-2-llm-providers-design.md
  - docs/integrations/api-audit.md
---

# Sub-project 3 — CEX Provider Real Implementations

## 1. Problem

After sub-project 1, 3 CEX providers (OKX, Bybit, Bitget) are registered as **stubs** that return `not_implemented`. The other 2 CEX providers (Binance, Freqtrade) are already real. This sub-project implements real `test_connection` for the 3 remaining CEX providers.

## 2. Goals

1. Implement 3 real CEX adapters using each provider's **public** time endpoint (no auth required for health check).
2. Preserve the `credentials` dict shape (`api_key` / `secret` / `passphrase`) in the schema, even though the health check itself is unauthenticated — this keeps the door open for future private-endpoint calls (order placement, balance query) without schema migration.
3. Document the private auth pattern in code comments so a future implementer knows what headers to set.
4. Update `docs/integrations/api-audit.md` CEX section (replace 3 stub entries with full entries).
5. No new dependencies. Pure code addition.

## 3. Non-Goals

- Implementing private API calls (order placement, balance query, etc.). Future sub-projects.
- HMAC signature computation. Out of scope; we only hit public endpoints.
- Rate-limit header parsing (public `/time` endpoints aren't rate-limited).
- WebSocket / real-time order book. Sub-project 7.

## 4. Provider-Specific Reference

### 4.1 OKXProvider

- **Auth (for health check):** None — `GET /api/v5/public/time` is public
- **Auth (for future private calls, documented only):** HMAC SHA256
  - Headers: `OK-ACCESS-KEY`, `OK-ACCESS-SIGN`, `OK-ACCESS-TIMESTAMP`, `OK-ACCESS-PASSPHRASE`
- **Base URL:** `https://www.okx.com` (configurable)
- **Health endpoint:** `GET /api/v5/public/time` (no token cost, no rate limit)
- **Response shape:** `{"code":"0","msg":"","data":[{"ts":"1700000000000"}]}`
- **Rate-limit headers:** None (public endpoint)
- **Error codes:** 200 (regardless of `code` field; check 200) → ACTIVE; 401/403 → INACTIVE; 5xx → ERROR
- **Config schema:** `OKXConfig { base_url, timeout_s }`
- **Credentials dict shape (for future use):** `{"api_key": "...", "secret": "...", "passphrase": "..."}`

### 4.2 BybitProvider

- **Auth (for health check):** None — `GET /v5/market/time` is public
- **Auth (for future private calls, documented only):** HMAC SHA256
  - Headers: `X-BAPI-API-KEY`, `X-BAPI-SIGN`, `X-BAPI-TIMESTAMP`, `X-BAPI-RECV-WINDOW`
- **Base URL:** `https://api.bybit.com` (configurable; `.testnet` for testing)
- **Health endpoint:** `GET /v5/market/time` (no token cost, no rate limit)
- **Response shape:** `{"retCode":0,"retMsg":"OK","result":{"timeSecond":"1700000000","timeNano":"1700000000000000000"},"retExtInfo":{}}`
- **Rate-limit headers:** Not documented for public endpoints
- **Error codes:** 200 → ACTIVE; 401/403 → INACTIVE; 5xx → ERROR
- **Config schema:** `BybitConfig { base_url, timeout_s }`
- **Credentials dict shape (for future use):** `{"api_key": "...", "secret": "..."}`

### 4.3 BitgetProvider

- **Auth (for health check):** None — `GET /api/v2/public/time` is public
- **Auth (for future private calls, documented only):** HMAC SHA256
  - Headers: `ACCESS-KEY`, `ACCESS-SIGN`, `ACCESS-TIMESTAMP`, `ACCESS-PASSPHRASE`
- **Base URL:** `https://api.bitget.com` (configurable)
- **Health endpoint:** `GET /api/v2/public/time` (no token cost, no rate limit)
- **Response shape:** `{"code":"00000","msg":"success","data":[{"serverTime":1700000000000}]}`
- **Rate-limit headers:** Not documented for public endpoints
- **Error codes:** 200 → ACTIVE; 401/403 → INACTIVE; 5xx → ERROR
- **Config schema:** `BitgetConfig { base_url, timeout_s }`
- **Credentials dict shape (for future use):** `{"api_key": "...", "secret": "...", "passphrase": "..."}`

## 5. Architecture

### 5.1 File Layout

New code under `backend/app/services/providers/categories/cex/`:

```
categories/cex/
├── __init__.py          # updated: register 3 new real classes
├── binance.py           # existing
├── freqtrade.py         # existing
├── okx.py               # NEW
├── bybit.py             # NEW
└── bitget.py            # NEW
```

Test files:

```
tests/providers/categories/cex/
├── test_cex_binance.py  # existing
├── test_cex_freqtrade.py # existing
├── test_okx.py          # NEW
├── test_bybit.py        # NEW
└── test_bitget.py       # NEW
```

### 5.2 Adapter Pattern (per provider)

Each follows the same shape as `BinanceProvider` (Task 2.3):

```python
class XxxConfig(BaseModel):
    base_url: str = Field(default=...)
    timeout_s: float = Field(default=10.0)

class XxxProvider:
    category = ProviderCategory.CEX
    provider_name = "..."
    is_multi_instance = False
    config_schema = XxxConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        """Hit the public /time endpoint. No auth needed."""
        ...

    async def fetch_rate_limit(self, credentials, config) -> RateLimitInfo | None:
        return None  # public endpoints aren't rate-limited

    def mask_config(self, config) -> dict:
        return dict(config)
```

### 5.3 Test Pattern (per provider)

Each test file has 3 tests:
- `test_200_returns_active` — mocks aiohttp returning 200
- `test_401_returns_inactive` — mocks 401
- `test_timeout_returns_error` — simulates network timeout

## 6. Data Model

**No schema changes.** Existing `provider_configs` table reused.

`credentials` dict is the only provider-specific storage. For these 3 CEX providers, the schema accepts:
```json
{
  "api_key": "...",
  "secret": "...",
  "passphrase": "..."  // only for OKX and Bitget
}
```

Validation: Pydantic's `LLMConfig`/`CEXConfig` discriminated union only checks `category`; the `credentials` dict is opaque. We do not validate credential shape at write time (deferred to private-endpoint implementation).

## 7. Status Mapping (unchanged from sub-project 1)

| Condition | Status |
|---|---|
| 200 OK | active |
| 401/403 Unauthorized | inactive |
| 5xx Server Error | error |
| timeout / connection error | error |

## 8. Migration

**No migration.** Pure code addition.

## 9. Documentation Updates

- **`docs/integrations/api-audit.md`** — replace the "OKX / Bybit / Bitget (stubs)" section with 3 full entries.

## 10. Testing Strategy

### Unit tests

Per provider, 3 mocked tests (mirroring `test_cex_binance.py`):
- happy path (200 → ACTIVE)
- 401 (auth fail → INACTIVE)
- timeout / network error → ERROR

### Smoke test

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.services.providers.categories import register_all
register_all()
from app.services.providers.registry import registry
print('CEX:', sorted(registry.list_providers('cex')))
"
```

Expected: `['binance', 'bitget', 'bybit', 'freqtrade', 'okx']` (5 CEX).

## 11. Implementation Order

1. Implement 3 providers (single PR preferred for atomicity)
2. Tests (3 files, ~9 tests total)
3. Update `categories/cex/__init__.py` to register the 3 new classes
4. Update `docs/integrations/api-audit.md`
5. Commit

## 12. Acceptance Criteria

- 3 new adapter files exist; 3 new test files exist
- All 9 new tests pass
- Existing 76 unit tests still pass
- `registry.list_providers('cex')` returns 5 providers
- `swift build` still passes
- `docs/integrations/api-audit.md` CEX section updated
- No new dependencies

## 13. Risks

| Risk | Mitigation |
|---|---|
| Public `/time` endpoints may rate-limit (DDOS protection) | Public endpoints typically have generous limits; if 429 happens, mark as ERROR (admin can re-test) |
| `api.bitget.com` URL may not work with the `/api/v2` prefix in all regions | Use the documented v2 URL; let `base_url` config override |
| Future private-endpoint calls will need HMAC signature logic | Out of scope for this round; documented in code comments |
| CEX returns 200 with error JSON in body (e.g., OKX `code != "0"`) | Health check only verifies HTTP 200; deep body parsing deferred |

## 14. Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` (sub-project 1)
- Spec: `docs/superpowers/specs/2026-06-16-sub-project-2-llm-providers-design.md` (sub-project 2 — similar pattern)
- API audit: `docs/integrations/api-audit.md` (CEX section to be updated)
