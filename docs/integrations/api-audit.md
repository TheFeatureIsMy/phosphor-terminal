# API Audit — Provider Integrations

This document lists every external product the backend integrates with, the
specific endpoints used, the auth method, and the rate-limit headers
expected. Real implementations (this round) are detailed in full; stub-only
providers list their official documentation URL for future implementation
(later sub-projects).

Last updated: 2026-06-16.

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

### OKX / Bybit / Bitget (stubs)
Real implementations deferred to sub-project 3.
- OKX: https://www.okx.com/docs-v5/en/
- Bybit: https://bybit-exchange.github.io/docs/v5/intro
- Bitget: https://www.bitget.com/api-doc/common/intro

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

### Discord / Email / Webhook (stubs)
Deferred to sub-project 6.

## Market Data, On-Chain, Social, News (all stubs)
- CoinGlass: https://coinglass.github.io/API-Reference/
- Glassnode: https://docs.glassnode.com/
- CryptoQuant: https://cryptoquant.github.io/public-api-docs/
- Whale Alert: https://docs.whale-alert.io/
- CryptoCompare: https://min-api.cryptocompare.com/documentation
- LunarCrush: https://lunarcrush.com/developers
- CryptoPanic: https://cryptopanic.com/api/v1/

## Rate-Limit Header Coverage

`RateLimitParser` recognizes:
- `X-RateLimit-Remaining`, `X-RateLimit-Limit`, `X-RateLimit-Reset` (standard)
- `X-MBX-USED-WEIGHT-1M` (Binance → `remaining = 6000 - used`)
- `X-Bapi-Limit-Status`, `X-Bapi-Limit` (Binance v3)
- `Coinglass-RateLimit-Remaining`
- `Retry-After` (HTTP standard)

Unknown providers / unknown headers fall through silently. The parser never raises into the request path.
