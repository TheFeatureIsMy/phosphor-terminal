# Sub-project 7 — Real-time WebSocket Aggregation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real-time WebSocket push path: backend broadcasts scheduler results, CCXT ticker stream updates in-memory cache, iOS gets a connect method.

**Tech Stack:** Python 3.12 / FastAPI WebSocket / CCXT (existing) / aiohttp / pytest. No new deps.

**Spec:** `docs/superpowers/specs/2026-06-17-sub-project-7-realtime-design.md`

**Use venv** at `backend/.venv/bin/python`.

---

## Task 1: ProviderHealthBroadcaster (in-memory pub/sub)

- [ ] **Step 1: Create `backend/app/services/providers/realtime/__init__.py`** (empty package init)

- [ ] **Step 2: Create `backend/app/services/providers/realtime/health_broadcaster.py`**:

```python
"""In-memory pub/sub for provider health updates.

Singleton. The scheduler calls publish() after every test_from_row;
the WebSocket route calls subscribe() per connection and yields from
the asyncio.Queue it returns.
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Any


class ProviderHealthBroadcaster:
    """Process-wide pub/sub. Thread-safe (asyncio)."""

    def __init__(self) -> None:
        self._subscribers: set[asyncio.Queue[dict[str, Any]]] = set()

    def subscribe(self) -> asyncio.Queue[dict[str, Any]]:
        q: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=100)
        self._subscribers.add(q)
        return q

    def unsubscribe(self, q: asyncio.Queue[dict[str, Any]]) -> None:
        self._subscribers.discard(q)

    def publish(self, message: dict[str, Any]) -> None:
        """Fan-out to all subscribers. Slow subscribers drop messages (queue full)."""
        for q in list(self._subscribers):
            try:
                q.put_nowait(message)
            except asyncio.QueueFull:
                # Drop the message for this subscriber; keep going
                pass


# Process-wide singleton
broadcaster = ProviderHealthBroadcaster()
```

- [ ] **Step 3: Create `backend/tests/providers/realtime/__init__.py`** (empty)

- [ ] **Step 4: Create `backend/tests/providers/realtime/test_health_broadcaster.py`**:

```python
"""Tests for ProviderHealthBroadcaster."""
from app.services.providers.realtime.health_broadcaster import ProviderHealthBroadcaster


def test_subscribe_publish_unsubscribe():
    b = ProviderHealthBroadcaster()
    q1 = b.subscribe()
    q2 = b.subscribe()
    b.publish({"type": "update", "n": 1})
    b.publish({"type": "update", "n": 2})
    assert q1.get_nowait() == {"type": "update", "n": 1}
    assert q2.get_nowait() == {"type": "update", "n": 1}
    assert q1.get_nowait() == {"type": "update", "n": 2}
    b.unsubscribe(q1)
    b.publish({"type": "update", "n": 3})
    # q1 should be gone
    assert q1.empty()
    # q2 should still receive
    assert q2.get_nowait() == {"type": "update", "n": 3}


def test_publish_does_not_block_on_full_queue():
    b = ProviderHealthBroadcaster()
    q = b.subscribe()
    # Fill the queue (maxsize=100)
    for i in range(150):
        b.publish({"i": i})
    # Should not raise; the latest messages are dropped for this subscriber
    assert q.qsize() <= 100
```

- [ ] **Step 5: Run + commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/realtime/test_health_broadcaster.py --noconftest -q 2>&1 | tail -3
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/realtime/ backend/tests/providers/realtime/ && git commit -m "feat(providers-realtime): add ProviderHealthBroadcaster singleton pub/sub"
```

---

## Task 2: TickerCache + CCXT ticker stream

- [ ] **Step 1: Create `backend/app/services/providers/realtime/ticker_cache.py`**:

```python
"""In-memory cache of latest ticker prices per symbol."""
from __future__ import annotations

import time
from typing import Any


class TickerCache:
    """Singleton. set/get latest ticker per symbol; entries expire after ttl_s."""

    def __init__(self, ttl_s: float = 60.0) -> None:
        self._data: dict[str, tuple[float, dict[str, Any]]] = {}
        self.ttl_s = ttl_s

    def set(self, symbol: str, ticker: dict[str, Any]) -> None:
        self._data[symbol] = (time.time(), ticker)

    def get(self, symbol: str) -> dict[str, Any] | None:
        if symbol not in self._data:
            return None
        ts, ticker = self._data[symbol]
        if time.time() - ts > self.ttl_s:
            del self._data[symbol]
            return None
        return ticker

    def all(self) -> dict[str, dict[str, Any]]:
        return {sym: t for sym, (ts, t) in self._data.items() if time.time() - ts <= self.ttl_s}


# Process-wide singleton
ticker_cache = TickerCache()
```

- [ ] **Step 2: Create `backend/tests/providers/realtime/test_ticker_cache.py`**:

```python
"""Tests for TickerCache."""
import time

from app.services.providers.realtime.ticker_cache import TickerCache


def test_set_and_get():
    c = TickerCache(ttl_s=10.0)
    c.set("BTC/USDT", {"last": 50000.0})
    assert c.get("BTC/USDT") == {"last": 50000.0}


def test_get_missing():
    c = TickerCache()
    assert c.get("NOPE") is None


def test_expiry():
    c = TickerCache(ttl_s=0.01)
    c.set("BTC/USDT", {"last": 1.0})
    time.sleep(0.02)
    assert c.get("BTC/USDT") is None


def test_all_filters_expired():
    c = TickerCache(ttl_s=0.01)
    c.set("A", {"v": 1})
    c.set("B", {"v": 2})
    time.sleep(0.02)
    c.set("C", {"v": 3})
    assert "A" not in c.all()
    assert "B" not in c.all()
    assert "C" in c.all()
```

- [ ] **Step 3: Create `backend/app/services/providers/realtime/ccxt_ticker_stream.py`**:

```python
"""CCXT Binance watch_ticker background stream. Updates TickerCache."""
from __future__ import annotations

import asyncio
import logging

logger = logging.getLogger(__name__)


async def run_binance_ticker_stream(symbols: list[str] | None = None) -> None:
    """Background task: subscribe to Binance public ticker stream.

    Updates ticker_cache.set() on every tick. Exits cleanly on cancellation.
    """
    if symbols is None:
        symbols = ["BTC/USDT"]
    from app.services.providers.realtime.ticker_cache import ticker_cache

    try:
        import ccxt.async_support as ccxt
    except ImportError:
        logger.warning("ccxt.async_support not available; ticker stream disabled")
        return

    exchange = ccxt.binance({"enableRateLimit": True})
    retries = 0
    while True:
        try:
            # CCXT async watch_ticker yields a dict per tick
            for symbol in symbols:
                while True:
                    ticker = await exchange.watch_ticker(symbol)
                    ticker_cache.set(symbol, {
                        "last": ticker.get("last"),
                        "bid": ticker.get("bid"),
                        "ask": ticker.get("ask"),
                        "volume": ticker.get("baseVolume"),
                        "ts": ticker.get("timestamp"),
                    })
                    retries = 0
        except asyncio.CancelledError:
            await exchange.close()
            raise
        except Exception as exc:
            retries += 1
            if retries > 3:
                logger.error("Ticker stream failed 3 times; giving up: %s", exc)
                await exchange.close()
                return
            backoff = 2 ** retries
            logger.warning("Ticker stream error (retry %d in %ds): %s", retries, backoff, exc)
            await asyncio.sleep(backoff)
```

- [ ] **Step 4: Run + commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/realtime/ --noconftest -q 2>&1 | tail -3
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/realtime/ticker_cache.py backend/app/services/providers/realtime/ccxt_ticker_stream.py backend/tests/providers/realtime/test_ticker_cache.py && git commit -m "feat(providers-realtime): add TickerCache + CCXT Binance ticker stream"
```

---

## Task 3: WebSocket route `/api/ws/provider-health`

- [ ] **Step 1: Create `backend/app/routers/providers_ws.py`**:

```python
"""WebSocket route for real-time provider health updates."""
from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.database import SessionLocal
from app.models.provider_config import ProviderConfig
from app.services.providers.config_service import ProviderConfigService
from app.services.providers.realtime.health_broadcaster import broadcaster

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/ws", tags=["providers-realtime"])


def _serialize_provider(row: ProviderConfig, view) -> dict[str, Any]:
    v = view.model_dump(mode="json")
    v["provider_id"] = row.id
    return v


@router.websocket("/provider-health")
async def provider_health_ws(websocket: WebSocket) -> None:
    await websocket.accept()
    queue = broadcaster.subscribe()
    svc = ProviderConfigService()
    try:
        # Send initial snapshot
        with SessionLocal() as db:
            rows = svc.list(db)
            view_list = [_serialize_provider(r, svc.to_view(r)) for r in rows]
        await websocket.send_json({
            "type": "snapshot",
            "ts": datetime.now(timezone.utc).isoformat(),
            "providers": view_list,
        })

        # Stream updates until disconnect
        while True:
            try:
                msg = await asyncio.wait_for(queue.get(), timeout=30.0)
                await websocket.send_json(msg)
            except asyncio.TimeoutError:
                # Send heartbeat to keep connection alive
                await websocket.send_json({"type": "heartbeat", "ts": datetime.now(timezone.utc).isoformat()})
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.exception("WebSocket error: %s", exc)
    finally:
        broadcaster.unsubscribe(queue)
```

- [ ] **Step 2: Wire it in main.py**

Open `backend/app/main.py` and add:
```python
from app.routers.providers_ws import router as providers_ws_router
from app.services.providers.realtime.ccxt_ticker_stream import run_binance_ticker_stream
# ...
app.include_router(providers_ws_router)

# In lifespan, after the existing scheduler start, add:
ticker_task = asyncio.create_task(run_binance_ticker_stream())
try:
    yield
finally:
    ticker_task.cancel()
    try:
        await ticker_task
    except asyncio.CancelledError:
        pass
    await sched.stop()
```

- [ ] **Step 3: Run + commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "from app.routers.providers_ws import router; print('ws routes:', [r.path for r in router.routes])"
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/routers/providers_ws.py backend/app/main.py && git commit -m "feat(providers-realtime): add /api/ws/provider-health WebSocket route + start ticker stream in lifespan"
```

---

## Task 4: iOS plumbing — `APIDataSources.connectProviderHealthStream()`

- [ ] **Step 1: Open `macos-app/AlphaLoop/Services/APIDataSources.swift`**

Find the existing methods and add a new method:

```swift
/// Connect to /api/ws/provider-health and return an AsyncStream of decoded messages.
public func connectProviderHealthStream() -> AsyncThrowingStream<ProviderHealthMessage, Error> {
    let url = baseURL.appendingPathComponent("/api/ws/provider-health")
    return AsyncThrowingStream { continuation in
        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        func receive() {
            task.receive { result in
                switch result {
                case .success(let message):
                    if let data = message.data(using: .utf8) {
                        do {
                            let msg = try decoder.decode(ProviderHealthMessage.self, from: data)
                            continuation.yield(msg)
                        } catch {
                            // Skip malformed frame
                        }
                    }
                    receive()
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
        }
        receive()
        continuation.onTermination = { _ in task.cancel(with: .goingAway, reason: nil) }
    }
}
```

And add the message type:
```swift
public struct ProviderHealthMessage: Codable {
    public let type: String
    public let ts: Date
    public let providers: [ProviderConfigView]?  // only on snapshot
    public let providerId: Int?  // only on update
    public let status: String?
    public let latencyMs: Int?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case type, ts, providers, status, error
        case providerId = "provider_id"
        case latencyMs = "latency_ms"
    }
}
```

- [ ] **Step 2: Build + commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -5
cd /Users/novspace/workspace/phosphor-terminal && git add macos-app/AlphaLoop/Services/APIDataSources.swift && git commit -m "feat(ios): add connectProviderHealthStream WebSocket plumbing to APIDataSources"
```

---

## Task 5: Update `docs/integrations/api-audit.md`

- [ ] **Step 1: Add a new section "## Real-time WebSocket Streams"** before "## Rate-Limit Header Coverage" with content:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/integrations/api-audit.md && git commit -m "docs: add Real-time WebSocket Streams section to api-audit.md"
```

---

## Acceptance Criteria

- 4 new test files (broadcaster, ticker cache, ws route, iOS) — all pass
- `/api/ws/provider-health` WebSocket accepts connections and sends initial snapshot
- `ticker_cache` populates from CCXT Binance stream (verified by `ticker_cache.get("BTC/USDT")` returning a dict)
- iOS `APIDataSources.connectProviderHealthStream()` compiles
- 5 commits in this round

**End of plan.**
