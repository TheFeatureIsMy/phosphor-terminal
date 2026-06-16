# Sub-project 3 — CEX Provider Real Implementations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 3 CEX provider adapters (OKX, Bybit, Bitget) that currently exist as stubs in the ProviderAdapter framework.

**Architecture:** Each provider hits its public `/time` endpoint (no auth required) for health checks. Credentials dict shape preserved for future private-endpoint calls. All use the same `ProviderAdapter` protocol.

**Tech Stack:** Python 3.12 / FastAPI / Pydantic v2 / aiohttp / pytest (existing); no new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-17-sub-project-3-cex-providers-design.md`

**Use venv** at `backend/.venv/bin/python`.

---

## File Map

### New (backend)
- `app/services/providers/categories/cex/okx.py`
- `app/services/providers/categories/cex/bybit.py`
- `app/services/providers/categories/cex/bitget.py`
- `tests/providers/categories/cex/test_okx.py`
- `tests/providers/categories/cex/test_bybit.py`
- `tests/providers/categories/cex/test_bitget.py`

### Modified
- `app/services/providers/categories/cex/__init__.py` — register 3 new classes
- `docs/integrations/api-audit.md` — replace 3 CEX stub entries

---

### Task 1: OKXProvider

**Files:**
- Create: `backend/app/services/providers/categories/cex/okx.py`
- Create: `backend/tests/providers/categories/cex/test_okx.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/cex/test_okx.py`:

```python
"""Tests for the OKX CEX adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.cex.okx import OKXProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = OKXProvider()
    with patch("app.services.providers.categories.cex.okx.aiohttp.ClientSession") as M:
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
            {"api_key": "test", "secret": "test", "passphrase": "test"},
            {"base_url": "https://www.okx.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = OKXProvider()
    with patch("app.services.providers.categories.cex.okx.aiohttp.ClientSession") as M:
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
            {"api_key": "test", "secret": "test", "passphrase": "test"},
            {"base_url": "https://www.okx.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = OKXProvider()
    assert a.provider_name == "okx"
    assert a.category == ProviderCategory.CEX
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/cex/test_okx.py --noconftest -v
```

Expected: FAIL with `ModuleNotFoundError`

- [ ] **Step 3: Implement `okx.py`**

```python
"""OKX CEX adapter. Real implementation using public time endpoint."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class OKXConfig(BaseModel):
    base_url: str = Field(default="https://www.okx.com")
    timeout_s: float = Field(default=10.0)


class OKXProvider:
    """OKX CEX adapter.

    Health check uses the public /api/v5/public/time endpoint, which does
    NOT require authentication. For future private-endpoint calls
    (orders, balances), the credentials dict holds api_key / secret /
    passphrase; HMAC SHA256 signing would be added in that sub-project.
    """

    category = ProviderCategory.CEX
    provider_name = "okx"
    is_multi_instance = False
    config_schema = OKXConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        # credentials are accepted but not used for the public /time probe
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v5/public/time"
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
                    status = (
                        ProviderStatus.INACTIVE
                        if resp.status in (401, 403) else ProviderStatus.ERROR
                    )
                    return HealthCheckResult(
                        success=False, status=status,
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

- [ ] **Step 4: Run test (3 pass), commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/cex/test_okx.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/cex/okx.py backend/tests/providers/categories/cex/test_okx.py && git commit -m "feat(providers): add OKX CEX adapter (real, public /time probe)"
```

---

### Task 2: BybitProvider

**Files:**
- Create: `backend/app/services/providers/categories/cex/bybit.py`
- Create: `backend/tests/providers/categories/cex/test_bybit.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/cex/test_bybit.py`:

```python
"""Tests for the Bybit CEX adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.cex.bybit import BybitProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = BybitProvider()
    with patch("app.services.providers.categories.cex.bybit.aiohttp.ClientSession") as M:
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
            {"api_key": "test", "secret": "test"},
            {"base_url": "https://api.bybit.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = BybitProvider()
    with patch("app.services.providers.categories.cex.bybit.aiohttp.ClientSession") as M:
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
            {"api_key": "test", "secret": "test"},
            {"base_url": "https://api.bybit.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = BybitProvider()
    assert a.provider_name == "bybit"
    assert a.category == ProviderCategory.CEX
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/cex/bybit.py
"""Bybit CEX adapter. Real implementation using public market/time endpoint."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class BybitConfig(BaseModel):
    base_url: str = Field(default="https://api.bybit.com")
    timeout_s: float = Field(default=10.0)


class BybitProvider:
    """Bybit CEX adapter.

    Health check uses the public /v5/market/time endpoint, which does NOT
    require authentication. For future private-endpoint calls (orders,
    balances), the credentials dict holds api_key / secret; HMAC SHA256
    signing via X-BAPI-SIGN header would be added in that sub-project.
    """

    category = ProviderCategory.CEX
    provider_name = "bybit"
    is_multi_instance = False
    config_schema = BybitConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/v5/market/time"
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
                    status = (
                        ProviderStatus.INACTIVE
                        if resp.status in (401, 403) else ProviderStatus.ERROR
                    )
                    return HealthCheckResult(
                        success=False, status=status,
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
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/cex/test_bybit.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/cex/bybit.py backend/tests/providers/categories/cex/test_bybit.py && git commit -m "feat(providers): add Bybit CEX adapter (real, public /v5/market/time probe)"
```

---

### Task 3: BitgetProvider

**Files:**
- Create: `backend/app/services/providers/categories/cex/bitget.py`
- Create: `backend/tests/providers/categories/cex/test_bitget.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/cex/test_bitget.py`:

```python
"""Tests for the Bitget CEX adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.cex.bitget import BitgetProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = BitgetProvider()
    with patch("app.services.providers.categories.cex.bitget.aiohttp.ClientSession") as M:
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
            {"api_key": "test", "secret": "test", "passphrase": "test"},
            {"base_url": "https://api.bitget.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = BitgetProvider()
    with patch("app.services.providers.categories.cex.bitget.aiohttp.ClientSession") as M:
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
            {"api_key": "test", "secret": "test", "passphrase": "test"},
            {"base_url": "https://api.bitget.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = BitgetProvider()
    assert a.provider_name == "bitget"
    assert a.category == ProviderCategory.CEX
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/cex/bitget.py
"""Bitget CEX adapter. Real implementation using public time endpoint."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class BitgetConfig(BaseModel):
    base_url: str = Field(default="https://api.bitget.com")
    timeout_s: float = Field(default=10.0)


class BitgetProvider:
    """Bitget CEX adapter.

    Health check uses the public /api/v2/public/time endpoint, which does
    NOT require authentication. For future private-endpoint calls
    (orders, balances), the credentials dict holds api_key / secret /
    passphrase; HMAC SHA256 signing via ACCESS-SIGN header would be
    added in that sub-project.
    """

    category = ProviderCategory.CEX
    provider_name = "bitget"
    is_multi_instance = False
    config_schema = BitgetConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v2/public/time"
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
                    status = (
                        ProviderStatus.INACTIVE
                        if resp.status in (401, 403) else ProviderStatus.ERROR
                    )
                    return HealthCheckResult(
                        success=False, status=status,
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
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/cex/test_bitget.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/cex/bitget.py backend/tests/providers/categories/cex/test_bitget.py && git commit -m "feat(providers): add Bitget CEX adapter (real, public /api/v2/public/time probe)"
```

---

### Task 4: Register 3 new CEX providers

**Files:**
- Modify: `backend/app/services/providers/categories/cex/__init__.py`

- [ ] **Step 1: Read the current file**

```bash
cat /Users/novspace/workspace/phosphor-terminal/backend/app/services/providers/categories/cex/__init__.py
```

- [ ] **Step 2: Replace the file with**

```python
"""CEX provider registrations."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

from app.services.providers.categories.cex.binance import BinanceProvider
from app.services.providers.categories.cex.freqtrade import FreqtradeProvider
from app.services.providers.categories.cex.okx import OKXProvider
from app.services.providers.categories.cex.bybit import BybitProvider
from app.services.providers.categories.cex.bitget import BitgetProvider


for _cls in (
    BinanceProvider, FreqtradeProvider,
    OKXProvider, BybitProvider, BitgetProvider,
):
    registry.register(_cls)
```

- [ ] **Step 3: Smoke test registration**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.services.providers.categories import register_all
register_all()
from app.services.providers.registry import registry
print('CEX:', sorted(registry.list_providers('cex')))
"
```

Expected: `['binance', 'bitget', 'bybit', 'freqtrade', 'okx']` (5 CEX).

- [ ] **Step 4: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/cex/__init__.py && git commit -m "feat(providers): register 3 new CEX providers (okx/bybit/bitget)"
```

---

### Task 5: Update `docs/integrations/api-audit.md` CEX section

**Files:**
- Modify: `docs/integrations/api-audit.md`

- [ ] **Step 1: Find the stub line**

```bash
cd /Users/novspace/workspace/phosphor-terminal && grep -n "stubs" docs/integrations/api-audit.md
```

Find the line beginning `### OKX / Bybit / Bitget (stubs)`.

- [ ] **Step 2: Replace the stub block with 3 full entries**

```markdown
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
```

- [ ] **Step 3: Verify line count**

```bash
wc -l /Users/novspace/workspace/phosphor-terminal/docs/integrations/api-audit.md
```

Expected: ≥ 200 lines.

- [ ] **Step 4: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/integrations/api-audit.md && git commit -m "docs: expand CEX section in api-audit.md (3 real providers)"
```

---

## Self-Review (for the implementer, before claiming done)

- [ ] All 3 new test files exist; all 9 new tests pass
- [ ] Existing 76 unit tests still pass
- [ ] `registry.list_providers('cex')` returns 5 providers
- [ ] `swift build` still passes
- [ ] `docs/integrations/api-audit.md` CEX section is fully expanded

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-17-sub-project-3-cex-providers-design.md`
- Plan: `docs/superpowers/plans/2026-06-17-sub-project-3-cex-providers.md`
- Foundation: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md`

**End of plan.**
