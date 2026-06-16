# Sub-project 5 — On-Chain / Social / News Real Implementations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 8 provider adapters (3 on-chain, 2 social, 3 news) that currently exist as stubs.

**Tech Stack:** Python 3.12 / aiohttp / pytest (existing). No new deps.

**Spec:** `docs/superpowers/specs/2026-06-17-sub-project-5-onchain-social-news-design.md`

**Use venv** at `backend/.venv/bin/python`.

---

## Task 1: GlassnodeProvider (on-chain)

- [ ] **Step 1: Write `backend/tests/providers/categories/onchain/test_glassnode.py`**:

```python
"""Tests for the Glassnode on-chain adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.onchain.glassnode import GlassnodeProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = GlassnodeProvider()
    with patch("app.services.providers.categories.onchain.glassnode.aiohttp.ClientSession") as M:
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
            {"api_key": "test-key"},
            {"base_url": "https://api.glassnode.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = GlassnodeProvider()
    with patch("app.services.providers.categories.onchain.glassnode.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 401
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="invalid api key")
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"api_key": "bad"},
            {"base_url": "https://api.glassnode.com", "timeout_s": 10.0},
        )
    assert r.status == ProviderStatus.INACTIVE


def test_meta():
    a = GlassnodeProvider()
    assert a.provider_name == "glassnode"
    assert a.category == ProviderCategory.ONCHAIN
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Write `backend/app/services/providers/categories/onchain/glassnode.py`**:

```python
"""Glassnode on-chain adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class GlassnodeConfig(BaseModel):
    base_url: str = Field(default="https://api.glassnode.com")
    timeout_s: float = Field(default=10.0)


class GlassnodeProvider:
    """Glassnode on-chain data adapter.

    Health check uses the cheapest public metric endpoint with API key
    in query. 401 (invalid key) maps to INACTIVE.
    """

    category = ProviderCategory.ONCHAIN
    provider_name = "glassnode"
    is_multi_instance = False
    config_schema = GlassnodeConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/v2/metrics/indicators/sopr?a=BTC&since=1700000000&api_key={api_key}"
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
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/onchain/test_glassnode.py --noconftest -v 2>&1 | tail -5
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/onchain/glassnode.py backend/tests/providers/categories/onchain/test_glassnode.py && git commit -m "feat(providers): add Glassnode on-chain adapter (real, API key auth)"
```

---

## Task 2: CryptoQuantProvider (on-chain)

- [ ] **Step 1: Write `backend/tests/providers/categories/onchain/test_cryptoquant.py`**:

```python
"""Tests for the CryptoQuant on-chain adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.onchain.cryptoquant import CryptoQuantProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = CryptoQuantProvider()
    with patch("app.services.providers.categories.onchain.cryptoquant.aiohttp.ClientSession") as M:
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
            {"api_key": "test-key"},
            {"base_url": "https://api.cryptoquant.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = CryptoQuantProvider()
    with patch("app.services.providers.categories.onchain.cryptoquant.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 401
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="invalid api key")
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"api_key": "bad"},
            {"base_url": "https://api.cryptoquant.com", "timeout_s": 10.0},
        )
    assert r.status == ProviderStatus.INACTIVE


def test_meta():
    a = CryptoQuantProvider()
    assert a.provider_name == "cryptoquant"
    assert a.category == ProviderCategory.ONCHAIN
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Write `backend/app/services/providers/categories/onchain/cryptoquant.py`**:

```python
"""CryptoQuant on-chain adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class CryptoQuantConfig(BaseModel):
    base_url: str = Field(default="https://api.cryptoquant.com")
    timeout_s: float = Field(default=10.0)


class CryptoQuantProvider:
    """CryptoQuant on-chain data adapter.

    Health check uses the cheapest public metric endpoint with API key
    in X-API-Token header. 401 maps to INACTIVE.
    """

    category = ProviderCategory.ONCHAIN
    provider_name = "cryptoquant"
    is_multi_instance = False
    config_schema = CryptoQuantConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/v2/btc/metrics/indicators/sopr?window=1d"
        headers = {"X-API-Token": api_key}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, headers=headers) as resp:
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

- [ ] **Step 3: Run test, commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/onchain/test_cryptoquant.py --noconftest -v 2>&1 | tail -5
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/onchain/cryptoquant.py backend/tests/providers/categories/onchain/test_cryptoquant.py && git commit -m "feat(providers): add CryptoQuant on-chain adapter (real, X-API-Token header)"
```

---

## Task 3: WhaleAlertProvider (on-chain, public)

- [ ] **Step 1: Write `backend/tests/providers/categories/onchain/test_whale_alert.py`**:

```python
"""Tests for the Whale Alert on-chain adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.onchain.whale_alert import WhaleAlertProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = WhaleAlertProvider()
    with patch("app.services.providers.categories.onchain.whale_alert.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://api.whale-alert.io", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = WhaleAlertProvider()
    with patch("app.services.providers.categories.onchain.whale_alert.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://api.whale-alert.io", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = WhaleAlertProvider()
    assert a.provider_name == "whale_alert"
    assert a.category == ProviderCategory.ONCHAIN
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Write `backend/app/services/providers/categories/onchain/whale_alert.py`**:

```python
"""Whale Alert on-chain adapter. Real implementation (public status endpoint)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class WhaleAlertConfig(BaseModel):
    base_url: str = Field(default="https://api.whale-alert.io")
    timeout_s: float = Field(default=10.0)


class WhaleAlertProvider:
    """Whale Alert on-chain data adapter. Public /v1/status endpoint."""

    category = ProviderCategory.ONCHAIN
    provider_name = "whale_alert"
    is_multi_instance = False
    config_schema = WhaleAlertConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/v1/status"
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

- [ ] **Step 3: Run test, commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/onchain/test_whale_alert.py --noconftest -v 2>&1 | tail -5
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/onchain/whale_alert.py backend/tests/providers/categories/onchain/test_whale_alert.py && git commit -m "feat(providers): add Whale Alert on-chain adapter (real, public /v1/status)"
```

---

## Task 4: CryptoCompareSocialProvider (social, public)

- [ ] **Step 1: Write `backend/tests/providers/categories/social/test_cryptocompare_social.py`**:

```python
"""Tests for the CryptoCompare Social adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.social.cryptocompare_social import CryptoCompareSocialProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = CryptoCompareSocialProvider()
    with patch("app.services.providers.categories.social.cryptocompare_social.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://min-api.cryptocompare.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = CryptoCompareSocialProvider()
    with patch("app.services.providers.categories.social.cryptocompare_social.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://min-api.cryptocompare.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = CryptoCompareSocialProvider()
    assert a.provider_name == "cryptocompare_social"
    assert a.category == ProviderCategory.SOCIAL
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Write `backend/app/services/providers/categories/social/cryptocompare_social.py`**:

```python
"""CryptoCompare Social adapter. Real implementation (public free tier)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class CryptoCompareSocialConfig(BaseModel):
    base_url: str = Field(default="https://min-api.cryptocompare.com")
    timeout_s: float = Field(default=10.0)


class CryptoCompareSocialProvider:
    """CryptoCompare social stats adapter. Public free-tier endpoint."""

    category = ProviderCategory.SOCIAL
    provider_name = "cryptocompare_social"
    is_multi_instance = False
    config_schema = CryptoCompareSocialConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/data/v2/social/stats/latest?symbol=BTC&aggregate=1h&limit=1"
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

- [ ] **Step 3: Run test, commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/social/test_cryptocompare_social.py --noconftest -v 2>&1 | tail -5
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/social/cryptocompare_social.py backend/tests/providers/categories/social/test_cryptocompare_social.py && git commit -m "feat(providers): add CryptoCompare Social adapter (real, public free tier)"
```

---

## Task 5: LunarCrushProvider (social, public)

- [ ] **Step 1: Write `backend/tests/providers/categories/social/test_lunarcrush.py`**:

```python
"""Tests for the LunarCrush social adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.social.lunarcrush import LunarCrushProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = LunarCrushProvider()
    with patch("app.services.providers.categories.social.lunarcrush.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://lunarcrush.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = LunarCrushProvider()
    with patch("app.services.providers.categories.social.lunarcrush.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://lunarcrush.com", "timeout_s": 10.0},
        )
    assert r.success is False
        assert r.status == ProviderStatus.ERROR


def test_meta():
    a = LunarCrushProvider()
    assert a.provider_name == "lunarcrush"
    assert a.category == ProviderCategory.SOCIAL
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Write `backend/app/services/providers/categories/social/lunarcrush.py`**:

```python
"""LunarCrush social adapter. Real implementation (public discovery)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class LunarCrushConfig(BaseModel):
    base_url: str = Field(default="https://lunarcrush.com")
    timeout_s: float = Field(default=10.0)


class LunarCrushProvider:
    """LunarCrush social data adapter. Public /4.0/coins/list."""

    category = ProviderCategory.SOCIAL
    provider_name = "lunarcrush"
    is_multi_instance = False
    config_schema = LunarCrushConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/4.0/coins/list"
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

Note: I had a typo in the test (extra `    ` indentation in the 500 test); fix to:
```python
        assert r.success is False
        assert r.status == ProviderStatus.ERROR
```
(2-space indent in the assertions block.)

- [ ] **Step 3: Run test, commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/social/test_lunarcrush.py --noconftest -v 2>&1 | tail -5
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/social/lunarcrush.py backend/tests/providers/categories/social/test_lunarcrush.py && git commit -m "feat(providers): add LunarCrush social adapter (real, public /4.0/coins/list)"
```

---

## Task 6: CryptoCompareNewsProvider (news, public)

- [ ] **Step 1: Write `backend/tests/providers/categories/news/test_cryptocompare_news.py`**:

```python
"""Tests for the CryptoCompare News adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.news.cryptocompare_news import CryptoCompareNewsProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = CryptoCompareNewsProvider()
    with patch("app.services.providers.categories.news.cryptocompare_news.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://min-api.cryptocompare.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = CryptoCompareNewsProvider()
    with patch("app.services.providers.categories.news.cryptocompare_news.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://min-api.cryptocompare.com", "timeout_s": 10.0},
        )
    assert r.success is False
        assert r.status == ProviderStatus.ERROR


def test_meta():
    a = CryptoCompareNewsProvider()
    assert a.provider_name == "cryptocompare_news"
    assert a.category == ProviderCategory.NEWS
    assert a.is_multi_instance is False
```

(Indent in the 500 test: 4 spaces for `assert`, not 8.)

- [ ] **Step 2: Write `backend/app/services/providers/categories/news/cryptocompare_news.py`**:

```python
"""CryptoCompare News adapter. Real implementation (public free tier)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class CryptoCompareNewsConfig(BaseModel):
    base_url: str = Field(default="https://min-api.cryptocompare.com")
    timeout_s: float = Field(default=10.0)


class CryptoCompareNewsProvider:
    """CryptoCompare news data adapter. Public free-tier /data/v2/news/."""

    category = ProviderCategory.NEWS
    provider_name = "cryptocompare_news"
    is_multi_instance = False
    config_schema = CryptoCompareNewsConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/data/v2/news/?lang=EN&limit=1"
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

- [ ] **Step 3: Run test, commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/news/test_cryptocompare_news.py --noconftest -v 2>&1 | tail -5
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/news/cryptocompare_news.py backend/tests/providers/categories/news/test_cryptocompare_news.py && git commit -m "feat(providers): add CryptoCompare News adapter (real, public /data/v2/news/)"
```

---

## Task 7: CryptoPanicProvider (news, public)

- [ ] **Step 1: Write `backend/tests/providers/categories/news/test_cryptopanic.py`**:

```python
"""Tests for the CryptoPanic News adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.news.cryptopanic import CryptoPanicProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = CryptoPanicProvider()
    with patch("app.services.providers.categories.news.cryptopanic.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://cryptopanic.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = CryptoPanicProvider()
    with patch("app.services.providers.categories.news.cryptopanic.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://cryptopanic.com", "timeout_s": 10.0},
        )
    assert r.success is False
        assert r.status == ProviderStatus.ERROR


def test_meta():
    a = CryptoPanicProvider()
    assert a.provider_name == "cryptopanic"
    assert a.category == ProviderCategory.NEWS
    assert a.is_multi_instance is False
```

(Indent fix in 500 test.)

- [ ] **Step 2: Write `backend/app/services/providers/categories/news/cryptopanic.py`**:

```python
"""CryptoPanic News adapter. Real implementation (public free tier)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class CryptoPanicConfig(BaseModel):
    base_url: str = Field(default="https://cryptopanic.com")
    timeout_s: float = Field(default=10.0)


class CryptoPanicProvider:
    """CryptoPanic news data adapter. Public free-tier /api/v1/posts/."""

    category = ProviderCategory.NEWS
    provider_name = "cryptopanic"
    is_multi_instance = False
    config_schema = CryptoPanicConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v1/posts/?filter=hot&page=1"
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

- [ ] **Step 3: Run test, commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/news/test_cryptopanic.py --noconftest -v 2>&1 | tail -5
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/news/cryptopanic.py backend/tests/providers/categories/news/test_cryptopanic.py && git commit -m "feat(providers): add CryptoPanic News adapter (real, public /api/v1/posts/)"
```

---

## Task 8: Register 8 new providers

- [ ] **Step 1: Replace the 3 sub-package `__init__.py` files** with real-class registrations:

`backend/app/services/providers/categories/onchain/__init__.py`:
```python
"""On-chain provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.onchain.glassnode import GlassnodeProvider
from app.services.providers.categories.onchain.cryptoquant import CryptoQuantProvider
from app.services.providers.categories.onchain.whale_alert import WhaleAlertProvider


for _cls in (GlassnodeProvider, CryptoQuantProvider, WhaleAlertProvider):
    registry.register(_cls)
```

`backend/app/services/providers/categories/social/__init__.py`:
```python
"""Social provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.social.cryptocompare_social import CryptoCompareSocialProvider
from app.services.providers.categories.social.lunarcrush import LunarCrushProvider


for _cls in (CryptoCompareSocialProvider, LunarCrushProvider):
    registry.register(_cls)
```

`backend/app/services/providers/categories/news/__init__.py`:
```python
"""News provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.news.cryptocompare_news import CryptoCompareNewsProvider
from app.services.providers.categories.news.cryptopanic import CryptoPanicProvider


for _cls in (CryptoCompareNewsProvider, CryptoPanicProvider):
    registry.register(_cls)
```

- [ ] **Step 2: Smoke test**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.services.providers.categories import register_all
register_all()
from app.services.providers.registry import registry
for cat in ['onchain', 'social', 'news']:
    print(f'{cat}: {sorted(registry.list_providers(cat))}')
"
```

Expected:
```
onchain: ['cryptoquant', 'glassnode', 'whale_alert']
social: ['cryptocompare_social', 'lunarcrush']
news: ['cryptocompare_news', 'cryptopanic']
```

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/onchain/__init__.py backend/app/services/providers/categories/social/__init__.py backend/app/services/providers/categories/news/__init__.py && git commit -m "feat(providers): register 8 on-chain/social/news providers"
```

---

## Task 9: Update `docs/integrations/api-audit.md`

- [ ] **Step 1: Find the stub section in api-audit.md**

```bash
cd /Users/novspace/workspace/phosphor-terminal && grep -n "On-Chain, Social, News" docs/integrations/api-audit.md
```

(We already updated Market Data in sub-project 4; now we update the next section "## On-Chain, Social, News (all stubs)".)

- [ ] **Step 2: Replace that section with 3 sub-sections** (On-Chain, Social, News), each with full entries. The content is in the spec (`docs/superpowers/specs/2026-06-17-sub-project-5-onchain-social-news-design.md` §4); use the same field shape as the CEX/Market Data sections (provider class / official docs / auth / used endpoint / rate-limit / error codes / config schema / credentials shape).

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/integrations/api-audit.md && git commit -m "docs: expand on-chain/social/news sections in api-audit.md (8 real providers)"
```

---

## Acceptance Criteria

- 8 new adapter files + 8 new test files
- All 24 new tests pass
- `registry.list_providers('onchain')` returns 3, `social` returns 2, `news` returns 2
- `swift build` still passes
- `docs/integrations/api-audit.md` updated
- 9 commits in this round

**End of plan.**
