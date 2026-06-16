---
title: Sub-project 7 — Real-time WebSocket Aggregation
status: approved
date: 2026-06-17
authors: claude (brainstorming skill)
related:
  - docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md
  - docs/integrations/api-audit.md
---

# Sub-project 7 — Real-time WebSocket Aggregation

## 1. Problem

After sub-projects 1-6, the backend has a health-check scheduler that polls providers every 60s. iOS clients must manually refresh to see updates. This sub-project adds a real-time push path:
- Backend WebSocket endpoint broadcasts scheduler results
- Backend CCXT WebSocket client streams Binance ticker data
- iOS subscribes to the new WS endpoint

## 2. Goals

1. Add a FastAPI WebSocket endpoint `/api/ws/provider-health` that streams provider health updates.
2. Add a CCXT WebSocket client wrapper for Binance public ticker (`watch_ticker`). Updates an in-memory cache.
3. iOS `NetworkClient` (existing) gets a `connectProviderHealthStream` method.
4. No new dependencies (FastAPI WebSocket support is built-in; CCXT is already a dep).

## 3. Non-Goals

- Multi-exchange WebSocket aggregation (sub-project 4.5+).
- Authenticated WS streams (user-specific, requires API key per connection).
- WS reconnect logic beyond "exponential backoff with 3 retries" stub.
- iOS UI changes (just plumbing).

## 4. Architecture

### 4.1 Backend

**New files:**
- `backend/app/services/providers/realtime/health_stream.py` — broadcasts scheduler results via a singleton `ProviderHealthBroadcaster` (in-memory pub/sub). Hooked into `ProviderHealthService` to call on every `test_from_row`.
- `backend/app/services/providers/realtime/ccxt_ticker_stream.py` — wraps CCXT `binance.watch_ticker("BTC/USDT")` in an async background task; stores latest price in `app.services.providers.realtime.cache.TickerCache`.
- `backend/app/routers/providers_ws.py` — FastAPI WebSocket endpoint `/api/ws/provider-health`. On connect: sends the current health-summary snapshot, then streams subsequent updates.
- `backend/tests/providers/realtime/test_health_broadcaster.py` — unit tests for broadcaster singleton (subscribe / publish / unsubscribe).
- `backend/tests/providers/realtime/test_ticker_cache.py` — unit tests for ticker cache (set / get latest).

**Modified:**
- `backend/app/main.py` — start ticker stream background task in lifespan; mount the new WS router.
- `macos-app/AlphaLoop/Services/APIDataSources.swift` — add `connectProviderHealthStream()` returning an `AsyncStream<ProviderHealthUpdate>`.

### 4.2 Message shapes

Server → Client messages on `/api/ws/provider-health`:

```json
// initial snapshot
{
  "type": "snapshot",
  "ts": "2026-06-17T12:00:00Z",
  "providers": [{"id": 1, "category": "llm", "provider_name": "openai", "status": "active", "last_sync_at": "..."}, ...]
}

// per-update
{
  "type": "update",
  "ts": "2026-06-17T12:01:00Z",
  "provider_id": 1,
  "status": "active",
  "latency_ms": 42,
  "error": null
}
```

## 5. Data Model

**No DB schema changes.** The new code uses in-memory state only (broadcaster queue, ticker cache). iOS plumbing only.

## 6. Testing Strategy

- Unit tests for the broadcaster singleton (pub/sub, multiple subscribers, no-leak).
- Unit tests for the ticker cache (set/get, expiry).
- Manual smoke test: start backend, open `wscat -c ws://localhost:8000/api/ws/provider-health`, watch messages.

## 7. Documentation Updates

- `docs/integrations/api-audit.md` — add a new section "Real-time WebSocket Streams" describing the broadcaster and the CCXT ticker stream.

## 8. Acceptance Criteria

- New WS endpoint streams `snapshot` + `update` messages
- CCXT ticker stream updates in-memory cache; reachable via `TickerCache.get("BTC/USDT")`
- iOS `APIDataSources.connectProviderHealthStream()` exists
- All existing tests still pass
- `swift build` passes
