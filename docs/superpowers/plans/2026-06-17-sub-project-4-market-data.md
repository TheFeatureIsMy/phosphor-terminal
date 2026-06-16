# Sub-project 4 — Market Data Provider Real Implementations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 4 Market Data provider adapters (kline, orderbook, funding, oi) that currently exist as stubs in the ProviderAdapter framework.

**Architecture:** All 4 providers use CCXT Binance's public `/api/v3/ping` for health checks. Each is an independent `ProviderAdapter` for a different data view. Future sub-projects add actual data-fetching methods.

**Tech Stack:** Python 3.12 / FastAPI / Pydantic v2 / aiohttp / pytest (existing); no new dependencies (CCXT already a dep).

**Spec:** `docs/superpowers/specs/2026-06-17-sub-project-4-market-data-design.md`

**Use venv** at `backend/.venv/bin/python`.

---

## File Map

### New (backend)
- `app/services/providers/categories/market_data/kline.py`
- `app/services/providers/categories/market_data/orderbook.py`
- `app/services/providers/categories/market_data/funding.py`
- `app/services/providers/categories/market_data/oi.py`
- `tests/providers/categories/market_data/test_kline.py`
- `tests/providers/categories/market_data/test_orderbook.py`
- `tests/providers/categories/market_data/test_funding.py`
- `tests/providers/categories/market_data/test_oi.py`

### Modified
- `app/services/providers/categories/market_data/__init__.py` — register 4 new classes
- `docs/integrations/api-audit.md` — replace 4 Market Data stub entries

---

### Task 1: KlineProvider

**Files:**
- Create: `backend/app/services/providers/categories/market_data/kline.py`
- Create: `backend/tests/providers/categories/market_data/test_kline.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/market_data/test_kline.py`:

```python
"""Tests for the Kline (CCXT Binance) market data adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.market_data.kline import KlineProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = KlineProvider()
    with patch("app.services.providers.categories.market_data.kline.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {}, {"base_url": "https://api.binance.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = KlineProvider()
    with patch("app.services.providers.categories.market_data.kline.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 500
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="server error")
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {}, {"base_url": "https://api.binance.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = KlineProvider()
    assert a.provider_name == "kline"
    assert a.category == ProviderCategory.MARKET_DATA
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/market_data/kline.py
"""Kline (CCXT Binance) market data adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class KlineConfig(BaseModel):
    base_url: str = Field(default="https://api.binance.com")
    timeout_s: float = Field(default=10.0)


class KlineProvider:
    """Kline market data adapter (CCXT Binance).

    Health check uses CCXT Binance's public /api/v3/ping endpoint. Future
    sub-projects will add a fetch_klines() method that wraps CCXT's
    fetch_ohlcv(). For now this is just a health probe.
    """

    category = ProviderCategory.MARKET_DATA
    provider_name = "kline"
    is_multi_instance = False
    config_schema = KlineConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v3/ping"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    body = await resp.text()
                    err = f"HTTP {resp.status}: {body[:120]}"
                    return HealthCheckResult(
                        success=False, status=ProviderStatus.ERROR,
                        latency_ms=latency, error=err,
                    )
        except Exception as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                latency_ms=None, error=str(exc)[:200],
            )

    async def fetch_rate_limit(self, credentials: dict, config: dict) -> RateLimitInfo | None:
        return None

    def mask_config(self, config: dict) -> dict:
        return dict(config)
```

- [ ] **Step 3: Run test (3 pass), commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/market_data/test_kline.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/market_data/kline.py backend/tests/providers/categories/market_data/test_kline.py && git commit -m "feat(providers): add Kline (CCXT Binance) market data adapter (real)"
```

---

### Task 2: OrderbookProvider

**Files:**
- Create: `backend/app/services/providers/categories/market_data/orderbook.py`
- Create: `backend/tests/providers/categories/market_data/test_orderbook.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/market_data/test_orderbook.py`:

```python
"""Tests for the Orderbook (CCXT Binance) market data adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.market_data.orderbook import OrderbookProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = OrderbookProvider()
    with patch("app.services.providers.categories.market_data.orderbook.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {}, {"base_url": "https://api.binance.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = OrderbookProvider()
    with patch("app.services.providers.categories.market_data.orderbook.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 500
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="server error")
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {}, {"base_url": "https://api.binance.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = OrderbookProvider()
    assert a.provider_name == "orderbook"
    assert a.category == ProviderCategory.MARKET_DATA
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/market_data/orderbook.py
"""Orderbook (CCXT Binance) market data adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class OrderbookConfig(BaseModel):
    base_url: str = Field(default="https://api.binance.com")
    timeout_s: float = Field(default=10.0)


class OrderbookProvider:
    """Orderbook market data adapter (CCXT Binance)."""

    category = ProviderCategory.MARKET_DATA
    provider_name = "orderbook"
    is_multi_instance = False
    config_schema = OrderbookConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v3/ping"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    body = await resp.text()
                    err = f"HTTP {resp.status}: {body[:120]}"
                    return HealthCheckResult(
                        success=False, status=ProviderStatus.ERROR,
                        latency_ms=latency, error=err,
                    )
        except Exception as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                latency_ms=None, error=str(exc)[:200],
            )

    async def fetch_rate_limit(self, credentials: dict, config: dict) -> RateLimitInfo | None:
        return None

    def mask_config(self, config: dict) -> dict:
        return dict(config)
```

- [ ] **Step 3: Run test (3 pass), commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/market_data/test_orderbook.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/market_data/orderbook.py backend/tests/providers/categories/market_data/test_orderbook.py && git commit -m "feat(providers): add Orderbook (CCXT Binance) market data adapter (real)"
```

---

### Task 3: FundingProvider

**Files:**
- Create: `backend/app/services/providers/categories/market_data/funding.py`
- Create: `backend/tests/providers/categories/market_data/test_funding.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/market_data/test_funding.py`:

```python
"""Tests for the Funding (CCXT Binance) market data adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.market_data.funding import FundingProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = FundingProvider()
    with patch("app.services.providers.categories.market_data.funding.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {}, {"base_url": "https://api.binance.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = FundingProvider()
    with patch("app.services.providers.categories.market_data.funding.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 500
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="server error")
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {}, {"base_url": "https://api.binance.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = FundingProvider()
    assert a.provider_name == "funding"
    assert a.category == ProviderCategory.MARKET_DATA
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/market_data/funding.py
"""Funding (CCXT Binance) market data adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class FundingConfig(BaseModel):
    base_url: str = Field(default="https://api.binance.com")
    timeout_s: float = Field(default=10.0)


class FundingProvider:
    """Funding rate market data adapter (CCXT Binance)."""

    category = ProviderCategory.MARKET_DATA
    provider_name = "funding"
    is_multi_instance = False
    config_schema = FundingConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v3/ping"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    body = await resp.text()
                    err = f"HTTP {resp.status}: {body[:120]}"
                    return HealthCheckResult(
                        success=False, status=ProviderStatus.ERROR,
                        latency_ms=latency, error=err,
                    )
        except Exception as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                latency_ms=None, error=str(exc)[:200],
            )

    async def fetch_rate_limit(self, credentials: dict, config: dict) -> RateLimitInfo | None:
        return None

    def mask_config(self, config: dict) -> dict:
        return dict(config)
```

- [ ] **Step 3: Run test (3 pass), commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/market_data/test_funding.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/market_data/funding.py backend/tests/providers/categories/market_data/test_funding.py && git commit -m "feat(providers): add Funding (CCXT Binance) market data adapter (real)"
```

---

### Task 4: OIProvider

**Files:**
- Create: `backend/app/services/providers/categories/market_data/oi.py`
- Create: `backend/tests/providers/categories/market_data/test_oi.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/market_data/test_oi.py`:

```python
"""Tests for the OI (CCXT Binance) market data adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.market_data.oi import OIProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = OIProvider()
    with patch("app.services.providers.categories.market_data.oi.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {}, {"base_url": "https://api.binance.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = OIProvider()
    with patch("app.services.providers.categories.market_data.oi.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 500
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="server error")
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {}, {"base_url": "https://api.binance.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = OIProvider()
    assert a.provider_name == "oi"
    assert a.category == ProviderCategory.MARKET_DATA
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/market_data/oi.py
"""OI (CCXT Binance) market data adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class OIConfig(BaseModel):
    base_url: str = Field(default="https://api.binance.com")
    timeout_s: float = Field(default=10.0)


class OIProvider:
    """Open Interest market data adapter (CCXT Binance)."""

    category = ProviderCategory.MARKET_DATA
    provider_name = "oi"
    is_multi_instance = False
    config_schema = OIConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v3/ping"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    body = await resp.text()
                    err = f"HTTP {resp.status}: {body[:120]}"
                    return HealthCheckResult(
                        success=False, status=ProviderStatus.ERROR,
                        latency_ms=latency, error=err,
                    )
        except Exception as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                latency_ms=None, error=str(exc)[:200],
            )

    async def fetch_rate_limit(self, credentials: dict, config: dict) -> RateLimitInfo | None:
        return None

    def mask_config(self, config: dict) -> dict:
        return dict(config)
```

- [ ] **Step 3: Run test (3 pass), commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/market_data/test_oi.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/market_data/oi.py backend/tests/providers/categories/market_data/test_oi.py && git commit -m "feat(providers): add OI (CCXT Binance) market data adapter (real)"
```

---

### Task 5: Register 4 new market_data providers

**Files:**
- Modify: `backend/app/services/providers/categories/market_data/__init__.py`

- [ ] **Step 1: Replace the file with**

```python
"""Market data provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.market_data.kline import KlineProvider
from app.services.providers.categories.market_data.orderbook import OrderbookProvider
from app.services.providers.categories.market_data.funding import FundingProvider
from app.services.providers.categories.market_data.oi import OIProvider


for _cls in (KlineProvider, OrderbookProvider, FundingProvider, OIProvider):
    registry.register(_cls)
```

- [ ] **Step 2: Smoke test**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.services.providers.categories import register_all
register_all()
from app.services.providers.registry import registry
print('market_data:', sorted(registry.list_providers('market_data')))
"
```

Expected: `['funding', 'kline', 'oi', 'orderbook']` (4 market_data).

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/market_data/__init__.py && git commit -m "feat(providers): register 4 market_data providers (kline/orderbook/funding/oi)"
```

---

### Task 6: Update `docs/integrations/api-audit.md` Market Data section

**Files:**
- Modify: `docs/integrations/api-audit.md`

- [ ] **Step 1: Find the stub line**

```bash
cd /Users/novspace/workspace/phosphor-terminal && grep -n "CoinGlass (OI / funding)" docs/integrations/api-audit.md
```

Find the line beginning `- CoinGlass (OI / funding)`. The Market Data stubs are in this section.

- [ ] **Step 2: Replace the Market Data subsection (4 lines) with 4 full entries**

```markdown
### Market Data — Kline (real, CCXT Binance)
- **Provider class:** `app.services.providers.categories.market_data.kline.KlineProvider`
- **Underlying source:** CCXT Binance public API
- **Official docs:** https://docs.ccxt.com/#/exchanges/binance
- **Auth (health check):** None — uses public `/api/v3/ping`
- **Used endpoint:** `GET /api/v3/ping` (no token cost, no rate limit)
- **Future method:** `fetch_klines(symbol, timeframe, limit)` — deferred to sub-project 4.5
- **Rate-limit headers:** Not used (public ping)
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `KlineConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret"}`

### Market Data — Orderbook (real, CCXT Binance)
- **Provider class:** `app.services.providers.categories.market_data.orderbook.OrderbookProvider`
- **Underlying source:** CCXT Binance public API
- **Auth (health check):** None
- **Used endpoint:** `GET /api/v3/ping`
- **Future method:** `fetch_orderbook(symbol, limit=20)` — deferred
- **Rate-limit headers:** Not used
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `OrderbookConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret"}`

### Market Data — Funding (real, CCXT Binance)
- **Provider class:** `app.services.providers.categories.market_data.funding.FundingProvider`
- **Underlying source:** CCXT Binance public API
- **Auth (health check):** None
- **Used endpoint:** `GET /api/v3/ping`
- **Future method:** `fetch_funding_rate(symbol)` — deferred
- **Rate-limit headers:** Not used
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `FundingConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret"}`

### Market Data — OI (real, CCXT Binance)
- **Provider class:** `app.services.providers.categories.market_data.oi.OIProvider`
- **Underlying source:** CCXT Binance public API
- **Auth (health check):** None
- **Used endpoint:** `GET /api/v3/ping`
- **Future method:** `fetch_open_interest(symbol)` — deferred
- **Rate-limit headers:** Not used
- **Error codes:** 200 → ACTIVE; 5xx → ERROR
- **Config schema:** `OIConfig { base_url, timeout_s }`
- **Credentials dict shape (for future private calls):** `{"api_key", "secret"}`
```

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/integrations/api-audit.md && git commit -m "docs: expand Market Data section in api-audit.md (4 real providers)"
```

---

## Self-Review

- [ ] All 4 new test files exist; all 12 new tests pass
- [ ] Existing tests still pass
- [ ] `registry.list_providers('market_data')` returns 4 providers
- [ ] 6 commits in this round

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-17-sub-project-4-market-data-design.md`
- Plan: `docs/superpowers/plans/2026-06-17-sub-project-4-market-data.md`

**End of plan.**
