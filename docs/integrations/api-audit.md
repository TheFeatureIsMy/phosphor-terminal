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

### DeepSeek / Qwen / Zhipu / Moonshot / Gemini / Groq / Azure OpenAI (stubs)
Return `not_implemented`. Real implementations deferred to sub-project 2.
- DeepSeek: https://platform.deepseek.com/api-docs/
- Qwen: https://help.aliyun.com/zh/model-studio/developer-reference/api-reference
- Zhipu: https://open.bigmodel.cn/dev/api
- Moonshot: https://platform.moonshot.cn/docs/api-reference
- Gemini: https://ai.google.dev/gemini-api/docs
- Groq: https://console.groq.com/docs/api-reference
- Azure OpenAI: https://learn.microsoft.com/en-us/azure/ai-services/openai/reference

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
