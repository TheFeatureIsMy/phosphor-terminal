---
title: Sub-project 5 — On-Chain / Social / News Provider Real Implementations
status: approved
date: 2026-06-17
authors: claude (brainstorming skill)
supersedes: docs/integrations/api-audit.md (the 3 stub sections)
related:
  - docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md
  - docs/integrations/api-audit.md
---

# Sub-project 5 — On-Chain / Social / News Provider Real Implementations

## 1. Problem

After sub-project 1, 8 providers across 3 categories are registered as **stubs** that return `not_implemented`:

- **On-Chain:** glassnode, cryptoquant, whale_alert
- **Social:** cryptocompare_social, lunarcrush
- **News:** cryptocompare_news, cryptopanic

This sub-project implements real `test_connection` for all 8.

## 2. Goals

1. Implement 8 real adapters hitting each provider's cheapest public health endpoint.
2. For providers whose cheapest public call requires no auth, use that.
3. For providers whose cheapest public call requires an API key, document the auth requirement and use that endpoint (the health check verifies both connectivity AND that the configured key is valid).
4. Update `docs/integrations/api-audit.md` for all 3 categories (replace 8 stub entries).
5. No new dependencies. Pure code addition.

## 3. Non-Goals

- Implementing actual data-fetching methods (`fetch_social_sentiment()`, `fetch_news()`). Future sub-projects.
- Adding other providers (Santiment, Messari, etc.). Future sub-projects.
- WebSocket / streaming. Sub-project 7.

## 4. Provider-Specific Reference

### 4.1 On-Chain (3 providers)

| Provider | Health endpoint | Base URL | Auth |
|---|---|---|---|
| Glassnode | `GET /v2/metrics/indicators/sopr?a=BTC&since=1700000000` (cheap metric) | `https://api.glassnode.com` | API key in query (`?api_key=`) |
| CryptoQuant | `GET /v2/btc/metrics/indicators/sopr?window=1d` (cheap metric) | `https://api.cryptoquant.com` | API key in header (`X-API-Token`) |
| Whale Alert | `GET /v1/status` (public) | `https://api.whale-alert.io` | None |

### 4.2 Social (2 providers)

| Provider | Health endpoint | Base URL | Auth |
|---|---|---|---|
| CryptoCompare (social) | `GET /data/v2/social/stats/latest?symbol=BTC&aggregate=1h&limit=1` | `https://min-api.cryptocompare.com` | None (free tier) |
| LunarCrush | `GET /4.0/coins/list` (public discovery) | `https://lunarcrush.com` | None |

### 4.3 News (2 providers)

| Provider | Health endpoint | Base URL | Auth |
|---|---|---|---|
| CryptoCompare (news) | `GET /data/v2/news/?lang=EN&limit=1` | `https://min-api.cryptocompare.com` | None (free tier) |
| CryptoPanic | `GET /api/v1/posts/?filter=hot&page=1` | `https://cryptopanic.com` | None (free tier) |

## 5. Architecture

### 5.1 File Layout

New code under `backend/app/services/providers/categories/{onchain,social,news}/`.

```
onchain/   (3 new): glassnode.py, cryptoquant.py, whale_alert.py
social/    (2 new): cryptocompare_social.py, lunarcrush.py
news/      (2 new): cryptocompare_news.py, cryptopanic.py
```

Test files mirroring the adapter layout, 3 tests each = 24 tests total.

### 5.2 Adapter Pattern (per provider)

Each follows the same pattern as existing adapters (e.g., `BinanceProvider`):

```python
class XxxConfig(BaseModel):
    base_url: str = Field(default=...)
    api_key: str | None = None  # only if required
    timeout_s: float = Field(default=10.0)


class XxxProvider:
    category = ProviderCategory.ONCHAIN  # or SOCIAL or NEWS
    provider_name = "..."
    is_multi_instance = False
    config_schema = XxxConfig

    async def test_connection(self, credentials, config) -> HealthCheckResult:
        # Hit the cheapest public endpoint
        ...

    async def fetch_rate_limit(self, credentials, config) -> RateLimitInfo | None:
        return None

    def mask_config(self, config) -> dict:
        return dict(config)
```

For Glassnode and CryptoQuant, `api_key` is required. For others, no auth.

## 6. Data Model

**No schema changes.** `provider_configs.credentials` and `config` JSON fields hold:
- For auth-required providers: `{"api_key": "..."}` in credentials; `{"base_url": "..."}` in config
- For no-auth providers: credentials empty; `{"base_url": "..."}` in config

## 7. Status Mapping

| Condition | Status |
|---|---|
| 200 OK | active |
| 401/403 (auth fail, key invalid) | inactive |
| 5xx | error |
| timeout / network | error |

## 8. Migration

**No migration.** Pure code addition.

## 9. Documentation Updates

- `docs/integrations/api-audit.md` — replace 3 stub sections (On-Chain, Social, News) with 8 full entries.

## 10. Acceptance Criteria

- 8 new adapter files + 8 new test files exist
- All 24 new tests pass
- `registry.list_providers('onchain')` returns 3, `social` returns 2, `news` returns 2 (after update)
- `swift build` still passes
- `docs/integrations/api-audit.md` updated

## 11. Risks

| Risk | Mitigation |
|---|---|
| Public endpoints may rate-limit | Mark as ERROR if 429; admin can re-test |
| Glassnode / CryptoQuant require valid API key for health check | Documented; status=INACTIVE if 401 |
| Endpoint URLs may change | Use widely-documented public endpoints; defer private endpoints to future sub-projects |
