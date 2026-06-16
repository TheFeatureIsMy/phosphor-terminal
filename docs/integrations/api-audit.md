# API Audit — Provider Integrations

This document lists every external product the backend integrates with, the
specific endpoints used, the auth method, and the rate-limit headers
expected. Real implementations (this round) are detailed in full; stub-only
providers list their official documentation URL for future implementation
(later sub-projects).

Last updated: 2026-06-17.

## LLM Providers

### OpenAI (real)
- **Provider class:** `app.services.providers.categories.llm.openai.OpenAIProvider`
- **Official docs:** https://platform.openai.com/docs/api-reference
- **Auth:** Bearer token in `Authorization` header (`sk-...` API key)
- **Used endpoint:** `GET /v1/models` (probe — does not consume tokens)
- **Rate limit headers:** OpenAI does not return standard rate-limit headers on `/v1/models`. `RateLimitParser` returns `None`.
- **Config schema:** `OpenAIConfig { base_url, model, timeout_s }`

### Anthropic (real)
- **Provider class:** `app.services.providers.categories.llm.anthropic.AnthropicProvider`
- **Official docs:** https://docs.anthropic.com/en/api/messages
- **Auth:** `x-api-key` + `anthropic-version: 2023-06-01`
- **Used endpoint:** `POST /v1/messages` with `max_tokens: 1` and minimal user message
- **Rate limit headers:** `retry-after` and `x-ratelimit-*` on 429.
- **Config schema:** `AnthropicConfig { model, timeout_s }`

### Ollama (real, local)
- **Provider class:** `app.services.providers.categories.llm.ollama.OllamaProvider`
- **Official docs:** https://github.com/ollama/ollama/blob/main/docs/api.md
- **Auth:** None
- **Used endpoint:** `GET /api/tags`
- **Config schema:** `OllamaConfig { base_url, model, timeout_s }`

### DeepSeek (real)
- **Provider class:** `app.services.providers.categories.llm.deepseek.DeepSeekProvider`
- **Official docs:** https://api-docs.deepseek.com
- **Auth:** `Authorization: Bearer <api_key>` (OpenAI-compatible)
- **Used endpoint:** `GET /v1/models` (no token cost)
- **Rate-limit headers:** Not consistently documented; falls back to `Retry-After`
- **Error codes:** 401 → INACTIVE; 429 → RATE_LIMITED; 5xx → ERROR
- **Config schema:** `DeepSeekConfig { base_url, model, timeout_s }` (default model: `deepseek-chat`)

### Qwen (real, Alibaba DashScope compatible-mode)
- **Provider class:** `app.services.providers.categories.llm.qwen.QwenProvider`
- **Official docs:** https://help.aliyun.com/zh/model-studio/developer-reference/api-reference
- **Auth:** `Authorization: Bearer <api_key>` (compatible-mode)
- **Used endpoint:** `GET /compatible-mode/v1/models` (no token cost)
- **Rate-limit headers:** Not documented; falls back to `Retry-After`
- **Error codes:** 401 → INACTIVE; 429 → RATE_LIMITED; 5xx → ERROR
- **Config schema:** `QwenConfig { base_url, model, timeout_s }` (default model: `qwen-plus`)

### Zhipu (real, 智谱 GLM)
- **Provider class:** `app.services.providers.categories.llm.zhipu.ZhipuProvider`
- **Official docs:** https://open.bigmodel.cn/dev/api
- **Auth:** `Authorization: Bearer <api_key>` (OpenAI-compatible)
- **Used endpoint:** `GET /api/paas/v4/models` (no token cost)
- **Rate-limit headers:** Not documented; falls back to `Retry-After`
- **Error codes:** 401 → INACTIVE; 429 → RATE_LIMITED; 5xx → ERROR
- **Config schema:** `ZhipuConfig { base_url, model, timeout_s }` (default model: `glm-4`)

### Moonshot (real, 月之暗面 Kimi)
- **Provider class:** `app.services.providers.categories.llm.moonshot.MoonshotProvider`
- **Official docs:** https://platform.moonshot.cn/docs/api-reference
- **Auth:** `Authorization: Bearer <api_key>` (OpenAI-compatible)
- **Used endpoint:** `GET /v1/models` (no token cost)
- **Rate-limit headers:** Not documented; falls back to `Retry-After`
- **Error codes:** 401 → INACTIVE; 429 → RATE_LIMITED; 5xx → ERROR
- **Config schema:** `MoonshotConfig { base_url, model, timeout_s }` (default model: `moonshot-v1-8k`)

### Gemini (real, Google AI Studio)
- **Provider class:** `app.services.providers.categories.llm.gemini.GeminiProvider`
- **Official docs:** https://ai.google.dev/gemini-api/docs
- **Auth:** `?key=<api_key>` query param (NOT Bearer — Google standard)
- **Used endpoint:** `GET /v1beta/models?key=<key>&pageSize=1` (no token cost)
- **Rate-limit headers:** Not standardized; 429 on quota exceeded
- **Error codes:** 401/403 → INACTIVE; 429 → RATE_LIMITED; 503/504 → ERROR
- **Config schema:** `GeminiConfig { base_url, model, timeout_s }` (default model: `gemini-1.5-flash`)

### Groq (real)
- **Provider class:** `app.services.providers.categories.llm.groq.GroqProvider`
- **Official docs:** https://console.groq.com/docs
- **Auth:** `Authorization: Bearer <api_key>` (OpenAI-compatible)
- **Used endpoint:** `GET /openai/v1/models` (no token cost)
- **Rate-limit headers:** Full family — `x-ratelimit-limit-requests`, `x-ratelimit-remaining-requests`, `x-ratelimit-reset-requests`, `x-ratelimit-limit-tokens`, `x-ratelimit-remaining-tokens`, `x-ratelimit-reset-tokens`, `Retry-After`
- **Error codes:** 400 → ERROR; 401 → INACTIVE; 429 → RATE_LIMITED; 5xx → ERROR
- **Config schema:** `GroqConfig { base_url, model, timeout_s }` (default model: `llama-3.1-70b-versatile`)

### Azure OpenAI (real)
- **Provider class:** `app.services.providers.categories.llm.azure_openai.AzureOpenAIProvider`
- **Official docs:** https://learn.microsoft.com/en-us/azure/ai-services/openai/reference
- **Auth:** `api-key: <api_key>` header (NOT Bearer — Azure standard)
- **Used endpoint:** `POST {endpoint}/chat/completions?api-version=...` with 1-token body (minimal cost)
- **Rate-limit headers:** `Retry-After` on 429; others not standardized
- **Error codes:** 401 → INACTIVE; 404 → ERROR (deployment not found); 429 → RATE_LIMITED; 5xx → ERROR
- **Config schema:** `AzureOpenAIConfig { endpoint, deployment, api_version, model, timeout_s }`
- **Note:** Per-deployment URL; `endpoint` must include `/openai/deployments/{deployment}` path

## CEX Providers

### Binance (real)
- **Provider class:** `app.services.providers.categories.cex.binance.BinanceProvider`
- **Official docs:** https://binance-docs.github.io/apidocs/spot/en/
- **Auth:** None for `GET /api/v3/ping`; HMAC SHA256 for trading
- **Used endpoint:** `GET /api/v3/ping`
- **Rate limit headers:** `X-MBX-USED-WEIGHT-1M` (capacity 6000/min for spot)
- **Config schema:** `BinanceConfig { base_url, timeout_s }`

### Freqtrade (real)
- **Provider class:** `app.services.providers.categories.cex.freqtrade.FreqtradeProvider`
- **Official docs:** https://www.freqtrade.io/en/stable/rest-api/
- **Auth:** Basic auth
- **Used endpoint:** `GET /api/v1/ping` via `FreqtradeClient.ping()`
- **Config schema:** `FreqtradeConfig { url, username, password, timeout_s }`

### OKX (real)
- **Provider class:** `app.services.providers.categories.cex.okx.OKXProvider`
- **Official docs:** https://www.okx.com/docs-v5/en/
- **Auth (health check):** None — uses public endpoint
- **Auth (private, future):** HMAC SHA256 — headers `OK-ACCESS-KEY`, `OK-ACCESS-SIGN`, `OK-ACCESS-TIMESTAMP`, `OK-ACCESS-PASSPHRASE`
- **Used endpoint:** `GET /api/v5/public/time` (no token cost, no rate limit)
- **Rate-limit headers:** Not documented for public endpoints
- **Error codes:** 200 → ACTIVE; 401/403 → INACTIVE; 5xx → ERROR
- **Config schema:** `OKXConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret", "passphrase"}`

### Bybit (real)
- **Provider class:** `app.services.providers.categories.cex.bybit.BybitProvider`
- **Official docs:** https://bybit-exchange.github.io/docs/v5/intro
- **Auth (health check):** None — uses public endpoint
- **Auth (private, future):** HMAC SHA256 — headers `X-BAPI-API-KEY`, `X-BAPI-SIGN`, `X-BAPI-TIMESTAMP`, `X-BAPI-RECV-WINDOW`
- **Used endpoint:** `GET /v5/market/time` (no token cost, no rate limit)
- **Rate-limit headers:** Not documented for public endpoints
- **Error codes:** 200 → ACTIVE; 401/403 → INACTIVE; 5xx → ERROR
- **Config schema:** `BybitConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret"}`

### Bitget (real)
- **Provider class:** `app.services.providers.categories.cex.bitget.BitgetProvider`
- **Official docs:** https://www.bitget.com/api-doc/common/intro
- **Auth (health check):** None — uses public endpoint
- **Auth (private, future):** HMAC SHA256 — headers `ACCESS-KEY`, `ACCESS-SIGN`, `ACCESS-TIMESTAMP`, `ACCESS-PASSPHRASE`
- **Used endpoint:** `GET /api/v2/public/time` (no token cost, no rate limit)
- **Rate-limit headers:** Not documented for public endpoints
- **Error codes:** 200 → ACTIVE; 401/403 → INACTIVE; 5xx → ERROR
- **Config schema:** `BitgetConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret", "passphrase"}`

## DeX Providers (all stubs)
Real on-chain integration deferred to a later sub-project.
- GMX: https://docs.gmx.io/
- Hyperliquid: https://hyperliquid.gitbook.io/hyperliquid-docs
- dYdX: https://docs.dydx.exchange/

## Notification Providers

### Telegram (real)
- **Provider class:** `app.services.providers.categories.notification.telegram.TelegramProvider`
- **Official docs:** https://core.telegram.org/bots/api
- **Auth:** Bot token in URL path
- **Used endpoint:** `GET /getMe` (probes bot identity)
- **Rate limit headers:** `Retry-After` on 429
- **Config schema:** `TelegramConfig { dry_run, timeout_s }`

### Discord (real)
- **Provider class:** `app.services.providers.categories.notification.discord.DiscordProvider`
- **Official docs:** https://discord.com/developers/docs/resources/webhook
- **Auth:** Webhook URL (embedded token)
- **Used endpoint:** `HEAD {webhook_url}` (probes webhook validity)
- **Rate limit headers:** `X-RateLimit-*` standard family; `Retry-After` on 429
- **Error codes:** 204 → ACTIVE; 404 → INACTIVE (deleted webhook); 5xx → ERROR
- **Config schema:** `DiscordConfig { timeout_s }`
- **Credentials dict shape:** `{"webhook_url": "https://discord.com/api/webhooks/{id}/{token}"}`

### Email (real, SMTP)
- **Provider class:** `app.services.providers.categories.notification.email.EmailProvider`
- **Official docs:** https://docs.python.org/3/library/smtplib.html
- **Auth:** SMTP AUTH LOGIN (username + password)
- **Used endpoint:** SMTP connection to `{host}:{port}` + optional STARTTLS + login (does not send an email)
- **Rate limit headers:** N/A (protocol-level, not HTTP)
- **Error codes:** Successful login → ACTIVE; SMTPAuthenticationError → INACTIVE; connection/timeout → ERROR
- **Config schema:** `EmailConfig { host, port, use_tls, timeout_s }`
- **Credentials dict shape:** `{"username": "...", "password": "..."}`

### Webhook (real, generic HTTP POST)
- **Provider class:** `app.services.providers.categories.notification.webhook.WebhookProvider`
- **Official docs:** N/A — generic HTTP webhook contract
- **Auth:** Optional `Authorization` header via `auth_header` credential
- **Used endpoint:** `POST {url}` with `{"ping": true}` JSON body
- **Rate limit headers:** Depends on target server; standard `Retry-After` on 429
- **Error codes:** 2xx → ACTIVE; 5xx → ERROR
- **Config schema:** `WebhookConfig { url, timeout_s }`
- **Credentials dict shape:** `{"auth_header": "Bearer ..."}` (optional)

## Market Data (real, CCXT Binance)

All 4 market_data providers share CCXT Binance as the underlying source. Health check uses the public `/api/v3/ping` endpoint. Future sub-projects add data-fetching methods (`fetch_klines`, `fetch_orderbook`, `fetch_funding_rate`, `fetch_open_interest`).

### Kline (real)
- **Provider class:** `app.services.providers.categories.market_data.kline.KlineProvider`
- **Underlying source:** CCXT Binance public API
- **Official docs:** https://docs.ccxt.com/#/exchanges/binance
- **Auth (health check):** None — uses public `/api/v3/ping`
- **Used endpoint:** `GET /api/v3/ping` (no token cost, no rate limit)
- **Future method:** `fetch_klines(symbol, timeframe, limit)` — deferred
- **Rate-limit headers:** Not used (public ping)
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `KlineConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret"}`

### Orderbook (real)
- **Provider class:** `app.services.providers.categories.market_data.orderbook.OrderbookProvider`
- **Auth (health check):** None
- **Used endpoint:** `GET /api/v3/ping`
- **Future method:** `fetch_orderbook(symbol, limit=20)` — deferred
- **Rate-limit headers:** Not used
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `OrderbookConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret"}`

### Funding (real)
- **Provider class:** `app.services.providers.categories.market_data.funding.FundingProvider`
- **Auth (health check):** None
- **Used endpoint:** `GET /api/v3/ping`
- **Future method:** `fetch_funding_rate(symbol)` — deferred
- **Rate-limit headers:** Not used
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `FundingConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret"}`

### OI (real)
- **Provider class:** `app.services.providers.categories.market_data.oi.OIProvider`
- **Auth (health check):** None
- **Used endpoint:** `GET /api/v3/ping`
- **Future method:** `fetch_open_interest(symbol)` — deferred
- **Rate-limit headers:** Not used
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `OIConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret"}`

## On-Chain

### Glassnode (real)
- **Provider class:** `app.services.providers.categories.onchain.glassnode.GlassnodeProvider`
- **Official docs:** https://docs.glassnode.com/
- **Auth:** API key in query (`?api_key=<key>`) — required
- **Used endpoint:** `GET /v2/metrics/indicators/sopr?a=BTC&since=1700000000&api_key=...`
- **Rate-limit headers:** Not documented
- **Error codes:** 401 → INACTIVE; 5xx → ERROR
- **Config schema:** `GlassnodeConfig { base_url, timeout_s }`
- **Credentials dict shape:** `{"api_key": "..."}`

### CryptoQuant (real)
- **Provider class:** `app.services.providers.categories.onchain.cryptoquant.CryptoQuantProvider`
- **Official docs:** https://cryptoquant.github.io/public-api-docs/
- **Auth:** API key in `X-API-Token` header — required
- **Used endpoint:** `GET /v2/btc/metrics/indicators/sopr?window=1d`
- **Rate-limit headers:** Not documented
- **Error codes:** 401 → INACTIVE; 5xx → ERROR
- **Config schema:** `CryptoQuantConfig { base_url, timeout_s }`
- **Credentials dict shape:** `{"api_key": "..."}`

### Whale Alert (real)
- **Provider class:** `app.services.providers.categories.onchain.whale_alert.WhaleAlertProvider`
- **Official docs:** https://docs.whale-alert.io/
- **Auth:** None — public endpoint
- **Used endpoint:** `GET /v1/status` (no token cost)
- **Rate-limit headers:** Not documented
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `WhaleAlertConfig { base_url, timeout_s }`
- **Credentials dict shape:** (empty)

## Social

### CryptoCompare Social (real)
- **Provider class:** `app.services.providers.categories.social.cryptocompare_social.CryptoCompareSocialProvider`
- **Official docs:** https://min-api.cryptocompare.com/documentation
- **Auth:** None — public free tier
- **Used endpoint:** `GET /data/v2/social/stats/latest?symbol=BTC&aggregate=1h&limit=1`
- **Rate-limit headers:** Not documented
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `CryptoCompareSocialConfig { base_url, timeout_s }`
- **Credentials dict shape:** (empty)

### LunarCrush (real)
- **Provider class:** `app.services.providers.categories.social.lunarcrush.LunarCrushProvider`
- **Official docs:** https://lunarcrush.com/developers
- **Auth:** None — public discovery
- **Used endpoint:** `GET /4.0/coins/list`
- **Rate-limit headers:** Not documented
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `LunarCrushConfig { base_url, timeout_s }`
- **Credentials dict shape:** (empty)

## News

### CryptoCompare News (real)
- **Provider class:** `app.services.providers.categories.news.cryptocompare_news.CryptoCompareNewsProvider`
- **Official docs:** https://min-api.cryptocompare.com/documentation
- **Auth:** None — public free tier
- **Used endpoint:** `GET /data/v2/news/?lang=EN&limit=1`
- **Rate-limit headers:** Not documented
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `CryptoCompareNewsConfig { base_url, timeout_s }`
- **Credentials dict shape:** (empty)

### CryptoPanic (real)
- **Provider class:** `app.services.providers.categories.news.cryptopanic.CryptoPanicProvider`
- **Official docs:** https://cryptopanic.com/api/v1
- **Auth:** None — public free tier
- **Used endpoint:** `GET /api/v1/posts/?filter=hot&page=1`
- **Rate-limit headers:** Not documented
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `CryptoPanicConfig { base_url, timeout_s }`
- **Credentials dict shape:** (empty)

## Real-time WebSocket Streams

### Provider Health Stream
- **Endpoint:** `ws://<host>/api/ws/provider-health` (FastAPI WebSocket)
- **Protocol:** JSON
- **Initial frame:** `{"type": "snapshot", "ts": "...", "providers": [...]}`
- **Update frames:** `{"type": "update", "ts": "...", "provider_id": ..., "status": ..., "latency_ms": ..., "error": ...}`
- **Heartbeat:** `{"type": "heartbeat", "ts": "..."}` every 30s to keep connection alive
- **Backed by:** `app.services.providers.realtime.health_broadcaster` (in-memory pub/sub fed by `ProviderHealthService`)

### CCXT Binance Ticker Stream
- **Underlying source:** CCXT Binance public WebSocket `watch_ticker`
- **Symbols (default):** `BTC/USDT`
- **Update destination:** `app.services.providers.realtime.ticker_cache.TickerCache` (in-memory, 60s TTL)
- **Public access:** future sub-projects will expose `GET /api/providers/ticker/{symbol}` reading from the cache

## Rate-Limit Header Coverage

`RateLimitParser` recognizes:
- `X-RateLimit-Remaining`, `X-RateLimit-Limit`, `X-RateLimit-Reset` (standard)
- `X-MBX-USED-WEIGHT-1M` (Binance → `remaining = 6000 - used`)
- `X-Bapi-Limit-Status`, `X-Bapi-Limit` (Binance v3)
- `Coinglass-RateLimit-Remaining`
- `Retry-After` (HTTP standard)

Unknown providers / unknown headers fall through silently. The parser never raises into the request path.
