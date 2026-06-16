---
title: Sub-project 4 — Market Data Provider Real Implementations (Kline/Orderbook/Funding/OI)
status: approved
date: 2026-06-17
authors: claude (brainstorming skill)
supersedes: docs/integrations/api-audit.md (only the Market Data stub section)
related:
  - docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md
  - docs/superpowers/specs/2026-06-16-sub-project-2-llm-providers-design.md
  - docs/superpowers/specs/2026-06-17-sub-project-3-cex-providers-design.md
  - docs/integrations/api-audit.md
---

# Sub-project 4 — Market Data Provider Real Implementations

## 1. Problem

After sub-project 1, 4 Market Data providers are registered as **stubs** that return `not_implemented`:
- `kline` — candlestick/OHLCV data
- `orderbook` — order book depth data
- `funding` — perpetual funding rate data
- `oi` — open interest data

The framework (ProviderAdapter, registry, config_service, health_service, scheduler) is already built. This sub-project implements real `test_connection` for all 4.

## 2. Goals

1. Implement 4 real Market Data adapters using CCXT Binance as the underlying data source.
2. Health check uses CCXT's public `GET /api/v3/ping` endpoint (no auth required).
3. Preserve the `credentials` dict shape (`api_key` / `secret`) for future private CCXT calls.
4. Update `docs/integrations/api-audit.md` Market Data section (replace 4 stub entries with full entries).
5. No new dependencies (CCXT is already a project dependency, version 4.0+).
6. No schema changes. Pure code addition.

## 3. Non-Goals

- Implementing actual `fetch_klines()` / `fetch_orderbook()` / `fetch_funding_rate()` / `fetch_open_interest()` methods. These are future sub-projects.
- Adding other data sources (CoinGlass, CryptoCompare). Future sub-projects.
- WebSocket streaming. Sub-project 7.
- Real-time order book updates. Sub-project 7.

## 4. Provider-Specific Reference

### 4.1 KlineProvider

- **Underlying source:** CCXT Binance public OHLCV API
- **Auth (health check):** None — uses public `/api/v3/ping`
- **Auth (private, future):** CCXT Binance with `apiKey` + `secret`
- **Base URL:** `https://api.binance.com` (CCXT default)
- **Health endpoint:** `GET /api/v3/ping` (no token cost, no rate limit)
- **Future method:** `fetch_klines(symbol, timeframe, limit)` → returns OHLCV array
- **Rate-limit headers:** Not used (public ping)
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `KlineConfig { base_url, timeout_s }`
- **Credentials dict shape (for future):** `{"api_key": "...", "secret": "..."}`

### 4.2 OrderbookProvider

- **Underlying source:** CCXT Binance public order book API
- **Auth (health check):** None
- **Auth (private, future):** CCXT Binance
- **Base URL:** `https://api.binance.com`
- **Health endpoint:** `GET /api/v3/ping`
- **Future method:** `fetch_orderbook(symbol, limit=20)`
- **Rate-limit headers:** Not used
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `OrderbookConfig { base_url, timeout_s }`
- **Credentials dict shape (for future):** `{"api_key": "...", "secret": "..."}`

### 4.3 FundingProvider

- **Underlying source:** CCXT Binance public funding rate API
- **Auth (health check):** None
- **Auth (private, future):** CCXT Binance
- **Base URL:** `https://api.binance.com`
- **Health endpoint:** `GET /api/v3/ping`
- **Future method:** `fetch_funding_rate(symbol)`
- **Rate-limit headers:** Not used
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `FundingConfig { base_url, timeout_s }`
- **Credentials dict shape (for future):** `{"api_key": "...", "secret": "..."}`

### 4.4 OIProvider

- **Underlying source:** CCXT Binance public open interest API
- **Auth (health check):** None
- **Auth (private, future):** CCXT Binance
- **Base URL:** `https://api.binance.com`
- **Health endpoint:** `GET /api/v3/ping`
- **Future method:** `fetch_open_interest(symbol)`
- **Rate-limit headers:** Not used
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `OIConfig { base_url, timeout_s }`
- **Credentials dict shape (for future):** `{"api_key": "...", "secret": "..."}`

## 5. Architecture

### 5.1 File Layout

New code under `backend/app/services/providers/categories/market_data/`:

```
market_data/
├── __init__.py      # updated: register 4 new real classes
├── kline.py         # NEW
├── orderbook.py     # NEW
├── funding.py       # NEW
└── oi.py            # NEW
```

Test files:

```
tests/providers/categories/market_data/
├── test_kline.py
├── test_orderbook.py
├── test_funding.py
└── test_oi.py
```

### 5.2 Adapter Pattern (per provider)

```python
class XxxConfig(BaseModel):
    base_url: str = Field(default="https://api.binance.com")
    timeout_s: float = Field(default=10.0)


class XxxProvider:
    category = ProviderCategory.MARKET_DATA
    provider_name = "..."
    is_multi_instance = False
    config_schema = XxxConfig

    async def test_connection(self, credentials, config) -> HealthCheckResult:
        # CCXT Binance public ping
        ...

    async def fetch_rate_limit(self, credentials, config) -> RateLimitInfo | None:
        return None

    def mask_config(self, config) -> dict:
        return dict(config)
```

All 4 providers share the same `test_connection` implementation pattern (Binance public ping). They differ only in:
- `provider_name` (kline / orderbook / funding / oi)
- `config_schema` class name (KlineConfig / etc.)
- Future data-fetching methods (deferred)

This "duplication" is intentional — each is an independent `ProviderAdapter` representing a different data view, even though they share an underlying source.

### 5.3 Test Pattern (per provider)

Each test file has 3 tests (mirroring `test_cex_binance.py`):
- `test_200_returns_active` — mocks aiohttp returning 200
- `test_500_returns_error` — mocks 500
- `test_meta` — provider metadata assertions

## 6. Data Model

**No schema changes.** Existing `provider_configs` table reused.

`credentials` dict shape (for future use): `{"api_key": "...", "secret": "..."}`. Not validated at write time; deferred to future private-endpoint implementation.

## 7. Status Mapping (unchanged from sub-project 1)

| Condition | Status |
|---|---|
| 200 OK | active |
| 5xx Server Error | error |
| timeout / connection error | error |

(Public ping endpoints don't have meaningful 401/403; we skip INACTIVE for now.)

## 8. Migration

**No migration.** Pure code addition.

## 9. Documentation Updates

- **`docs/integrations/api-audit.md`** — replace the "Market Data, On-Chain, Social, News (all stubs)" section's Market Data subsection with 4 full entries.

## 10. Testing Strategy

### Unit tests

Per provider, 3 mocked tests. The test file uses the same pattern as `test_cex_binance.py`.

### Smoke test

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.services.providers.categories import register_all
register_all()
from app.services.providers.registry import registry
print('market_data:', sorted(registry.list_providers('market_data')))
"
```

Expected: `['funding', 'kline', 'oi', 'orderbook']` (4 market_data).

## 11. Implementation Order

1. Implement 4 providers (one PR or 4 PRs — single PR preferred for atomicity)
2. Tests (4 files, ~12 tests total)
3. Update `categories/market_data/__init__.py` to register 4 new classes
4. Update `docs/integrations/api-audit.md`
5. Commit

## 12. Acceptance Criteria

- 4 new adapter files exist; 4 new test files exist
- All 12 new tests pass
- Existing 88 unit tests (76 from sub-projects 1-2 + 12 from sub-project 3) still pass
- `registry.list_providers('market_data')` returns 4 providers
- `swift build` still passes
- `docs/integrations/api-audit.md` Market Data subsection updated
- No new dependencies

## 13. Risks

| Risk | Mitigation |
|---|---|
| CCXT Binance goes down → all 4 health checks fail | Same as existing CEXProvider; admin sees the error |
| 4 providers share the same health check (redundant?) | Intentional — each is a distinct `ProviderAdapter` for a different data view. Future sub-projects add data-fetching methods. |
| Public `/api/v3/ping` may rate-limit (DDOS protection) | Public endpoints have generous limits; if 429 happens, mark as ERROR |

## 14. Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` (sub-project 1)
- Spec: `docs/superpowers/specs/2026-06-16-sub-project-2-llm-providers-design.md` (sub-project 2)
- Spec: `docs/superpowers/specs/2026-06-17-sub-project-3-cex-providers-design.md` (sub-project 3)
- API audit: `docs/integrations/api-audit.md` (Market Data section to be updated)
