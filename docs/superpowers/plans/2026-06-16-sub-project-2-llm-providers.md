# Sub-project 2 — LLM Provider Real Implementations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 7 LLM provider adapters (DeepSeek, Qwen, Zhipu, Moonshot, Gemini, Groq, Azure OpenAI) that currently exist as stubs in the ProviderAdapter framework built in sub-project 1.

**Architecture:** Each provider follows the same `ProviderAdapter` pattern as existing OpenAI / Anthropic / Ollama. Most use Bearer auth + GET /models; Gemini uses ?key= query; Azure OpenAI uses api-key header + POST chat/completions. All `test_connection` results flow through the existing `ProviderHealthService` and `RateLimitParser`.

**Tech Stack:** Python 3.12 / FastAPI / Pydantic v2 / aiohttp / pytest + pytest-asyncio (existing); no new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-16-sub-project-2-llm-providers-design.md`

**Use venv** at `backend/.venv/bin/python` (Python 3.12 required for `Mapped[X | None]` syntax in existing models).

---

## File Map

### New (backend)
- `app/services/providers/categories/llm/deepseek.py`
- `app/services/providers/categories/llm/qwen.py`
- `app/services/providers/categories/llm/zhipu.py`
- `app/services/providers/categories/llm/moonshot.py`
- `app/services/providers/categories/llm/gemini.py`
- `app/services/providers/categories/llm/groq.py`
- `app/services/providers/categories/llm/azure_openai.py`
- `tests/providers/categories/llm/test_deepseek.py`
- `tests/providers/categories/llm/test_qwen.py`
- `tests/providers/categories/llm/test_zhipu.py`
- `tests/providers/categories/llm/test_moonshot.py`
- `tests/providers/categories/llm/test_gemini.py`
- `tests/providers/categories/llm/test_groq.py`
- `tests/providers/categories/llm/test_azure_openai.py`

### Modified
- `app/services/providers/categories/llm/__init__.py` — register 7 new classes
- `docs/integrations/api-audit.md` — replace LLM stub section with full entries

---

## PR-S: 7 LLM provider implementations

### Task 1: DeepSeekProvider

**Files:**
- Create: `backend/app/services/providers/categories/llm/deepseek.py`
- Create: `backend/tests/providers/categories/llm/test_deepseek.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/llm/test_deepseek.py`:

```python
"""Tests for the DeepSeek LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.deepseek import DeepSeekProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = DeepSeekProvider()
    with patch("app.services.providers.categories.llm.deepseek.aiohttp.ClientSession") as M:
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
            {"api_key": "sk-test"},
            {"base_url": "https://api.deepseek.com/v1", "model": "deepseek-chat"},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = DeepSeekProvider()
    with patch("app.services.providers.categories.llm.deepseek.aiohttp.ClientSession") as M:
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
            {"base_url": "https://api.deepseek.com/v1", "model": "deepseek-chat"},
        )
    assert r.status == ProviderStatus.INACTIVE


@pytest.mark.asyncio
async def test_missing_api_key_returns_error():
    a = DeepSeekProvider()
    r = await a.test_connection(
        {}, {"base_url": "https://api.deepseek.com/v1", "model": "deepseek-chat"},
    )
    assert r.success is False
    assert "api_key" in (r.error or "").lower()


def test_meta():
    a = DeepSeekProvider()
    assert a.provider_name == "deepseek"
    assert a.category == ProviderCategory.LLM
    assert a.is_multi_instance is True
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/llm/test_deepseek.py --noconftest -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.providers.categories.llm.deepseek'`

- [ ] **Step 3: Implement `deepseek.py`**

```python
"""DeepSeek LLM provider adapter. Real implementation (OpenAI-compatible)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class DeepSeekConfig(BaseModel):
    base_url: str = Field(default="https://api.deepseek.com/v1")
    model: str = Field(default="deepseek-chat")
    timeout_s: float = Field(default=10.0)


class DeepSeekProvider:
    category = ProviderCategory.LLM
    provider_name = "deepseek"
    is_multi_instance = True
    config_schema = DeepSeekConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/models"
        headers = {"Authorization": f"Bearer {api_key}"}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, headers=headers) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=rl,
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

- [ ] **Step 4: Run test to confirm it passes**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/llm/test_deepseek.py --noconftest -v
```

Expected: 4 tests passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/llm/deepseek.py backend/tests/providers/categories/llm/test_deepseek.py && git commit -m "feat(providers): add DeepSeek LLM provider adapter (real)"
```

---

### Task 2: QwenProvider (Alibaba DashScope, compatible-mode)

**Files:**
- Create: `backend/app/services/providers/categories/llm/qwen.py`
- Create: `backend/tests/providers/categories/llm/test_qwen.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/llm/test_qwen.py`:

```python
"""Tests for the Qwen (Alibaba DashScope) LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.qwen import QwenProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = QwenProvider()
    with patch("app.services.providers.categories.llm.qwen.aiohttp.ClientSession") as M:
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
            {"api_key": "sk-test"},
            {"base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1", "model": "qwen-plus"},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = QwenProvider()
    with patch("app.services.providers.categories.llm.qwen.aiohttp.ClientSession") as M:
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
            {"base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1", "model": "qwen-plus"},
        )
    assert r.status == ProviderStatus.INACTIVE


def test_meta():
    a = QwenProvider()
    assert a.provider_name == "qwen"
    assert a.category == ProviderCategory.LLM
    assert a.is_multi_instance is True
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/llm/test_qwen.py --noconftest -v
```

Expected: FAIL with `ModuleNotFoundError`

- [ ] **Step 3: Implement `qwen.py`**

```python
"""Qwen (Alibaba DashScope) LLM provider. Real implementation (OpenAI-compatible mode)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class QwenConfig(BaseModel):
    base_url: str = Field(default="https://dashscope.aliyuncs.com/compatible-mode/v1")
    model: str = Field(default="qwen-plus")
    timeout_s: float = Field(default=10.0)


class QwenProvider:
    category = ProviderCategory.LLM
    provider_name = "qwen"
    is_multi_instance = True
    config_schema = QwenConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/models"
        headers = {"Authorization": f"Bearer {api_key}"}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, headers=headers) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=rl,
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

- [ ] **Step 4: Run test, commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/llm/test_qwen.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/llm/qwen.py backend/tests/providers/categories/llm/test_qwen.py && git commit -m "feat(providers): add Qwen LLM provider adapter (real)"
```

Expected: 3 tests passed.

---

### Task 3: ZhipuProvider (智谱 GLM)

**Files:**
- Create: `backend/app/services/providers/categories/llm/zhipu.py`
- Create: `backend/tests/providers/categories/llm/test_zhipu.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/llm/test_zhipu.py`:

```python
"""Tests for the Zhipu (智谱 GLM) LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.zhipu import ZhipuProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = ZhipuProvider()
    with patch("app.services.providers.categories.llm.zhipu.aiohttp.ClientSession") as M:
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
            {"api_key": "sk-test"},
            {"base_url": "https://open.bigmodel.cn/api/paas/v4", "model": "glm-4"},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = ZhipuProvider()
    with patch("app.services.providers.categories.llm.zhipu.aiohttp.ClientSession") as M:
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
            {"base_url": "https://open.bigmodel.cn/api/paas/v4", "model": "glm-4"},
        )
    assert r.status == ProviderStatus.INACTIVE


def test_meta():
    a = ZhipuProvider()
    assert a.provider_name == "zhipu"
    assert a.category == ProviderCategory.LLM
    assert a.is_multi_instance is True
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/llm/zhipu.py
"""Zhipu (智谱 GLM) LLM provider. Real implementation (OpenAI-compatible)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class ZhipuConfig(BaseModel):
    base_url: str = Field(default="https://open.bigmodel.cn/api/paas/v4")
    model: str = Field(default="glm-4")
    timeout_s: float = Field(default=10.0)


class ZhipuProvider:
    category = ProviderCategory.LLM
    provider_name = "zhipu"
    is_multi_instance = True
    config_schema = ZhipuConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/models"
        headers = {"Authorization": f"Bearer {api_key}"}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, headers=headers) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=rl,
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
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/llm/test_zhipu.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/llm/zhipu.py backend/tests/providers/categories/llm/test_zhipu.py && git commit -m "feat(providers): add Zhipu LLM provider adapter (real)"
```

---

### Task 4: MoonshotProvider (月之暗面 Kimi)

**Files:**
- Create: `backend/app/services/providers/categories/llm/moonshot.py`
- Create: `backend/tests/providers/categories/llm/test_moonshot.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/llm/test_moonshot.py`:

```python
"""Tests for the Moonshot (月之暗面 Kimi) LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.moonshot import MoonshotProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = MoonshotProvider()
    with patch("app.services.providers.categories.llm.moonshot.aiohttp.ClientSession") as M:
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
            {"api_key": "sk-test"},
            {"base_url": "https://api.moonshot.cn/v1", "model": "moonshot-v1-8k"},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = MoonshotProvider()
    with patch("app.services.providers.categories.llm.moonshot.aiohttp.ClientSession") as M:
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
            {"base_url": "https://api.moonshot.cn/v1", "model": "moonshot-v1-8k"},
        )
    assert r.status == ProviderStatus.INACTIVE


def test_meta():
    a = MoonshotProvider()
    assert a.provider_name == "moonshot"
    assert a.category == ProviderCategory.LLM
    assert a.is_multi_instance is True
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/llm/moonshot.py
"""Moonshot (月之暗面 Kimi) LLM provider. Real implementation (OpenAI-compatible)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class MoonshotConfig(BaseModel):
    base_url: str = Field(default="https://api.moonshot.cn/v1")
    model: str = Field(default="moonshot-v1-8k")
    timeout_s: float = Field(default=10.0)


class MoonshotProvider:
    category = ProviderCategory.LLM
    provider_name = "moonshot"
    is_multi_instance = True
    config_schema = MoonshotConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/models"
        headers = {"Authorization": f"Bearer {api_key}"}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, headers=headers) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=rl,
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
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/llm/test_moonshot.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/llm/moonshot.py backend/tests/providers/categories/llm/test_moonshot.py && git commit -m "feat(providers): add Moonshot LLM provider adapter (real)"
```

---

### Task 5: GeminiProvider (Google AI Studio) — query auth, not Bearer

**Files:**
- Create: `backend/app/services/providers/categories/llm/gemini.py`
- Create: `backend/tests/providers/categories/llm/test_gemini.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/llm/test_gemini.py`:

```python
"""Tests for the Gemini (Google AI Studio) LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.gemini import GeminiProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = GeminiProvider()
    with patch("app.services.providers.categories.llm.gemini.aiohttp.ClientSession") as M:
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
            {"api_key": "AIza-test"},
            {"base_url": "https://generativelanguage.googleapis.com", "model": "gemini-1.5-flash"},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_403_returns_inactive():
    a = GeminiProvider()
    with patch("app.services.providers.categories.llm.gemini.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 403
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="permission denied")
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"api_key": "bad"},
            {"base_url": "https://generativelanguage.googleapis.com", "model": "gemini-1.5-flash"},
        )
    assert r.status == ProviderStatus.INACTIVE


@pytest.mark.asyncio
async def test_missing_api_key_returns_error():
    a = GeminiProvider()
    r = await a.test_connection(
        {}, {"base_url": "https://generativelanguage.googleapis.com", "model": "gemini-1.5-flash"},
    )
    assert r.success is False
    assert "api_key" in (r.error or "").lower()


def test_meta():
    a = GeminiProvider()
    assert a.provider_name == "gemini"
    assert a.category == ProviderCategory.LLM
    assert a.is_multi_instance is True
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/llm/gemini.py
"""Gemini (Google AI Studio) LLM provider. Real implementation (query-param auth)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class GeminiConfig(BaseModel):
    base_url: str = Field(default="https://generativelanguage.googleapis.com")
    model: str = Field(default="gemini-1.5-flash")
    timeout_s: float = Field(default=10.0)


class GeminiProvider:
    category = ProviderCategory.LLM
    provider_name = "gemini"
    is_multi_instance = True
    config_schema = GeminiConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        # Gemini uses ?key=<api_key> query param (not Bearer header)
        url = f"{cfg.base_url.rstrip('/')}/v1beta/models?key={api_key}&pageSize=1"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=rl,
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

- [ ] **Step 3: Run test (4 pass), commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/llm/test_gemini.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/llm/gemini.py backend/tests/providers/categories/llm/test_gemini.py && git commit -m "feat(providers): add Gemini LLM provider adapter (real, query-param auth)"
```

---

### Task 6: GroqProvider — Bearer auth + rich rate-limit headers

**Files:**
- Create: `backend/app/services/providers/categories/llm/groq.py`
- Create: `backend/tests/providers/categories/llm/test_groq.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/llm/test_groq.py`:

```python
"""Tests for the Groq LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.groq import GroqProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = GroqProvider()
    with patch("app.services.providers.categories.llm.groq.aiohttp.ClientSession") as M:
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
            {"api_key": "gsk-test"},
            {"base_url": "https://api.groq.com/openai/v1", "model": "llama-3.1-70b-versatile"},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = GroqProvider()
    with patch("app.services.providers.categories.llm.groq.aiohttp.ClientSession") as M:
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
            {"base_url": "https://api.groq.com/openai/v1", "model": "llama-3.1-70b-versatile"},
        )
    assert r.status == ProviderStatus.INACTIVE


@pytest.mark.asyncio
async def test_rate_limit_headers_parsed():
    """Groq returns x-ratelimit-* family; verify parser captures them."""
    a = GroqProvider()
    with patch("app.services.providers.categories.llm.groq.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.headers = {
            "x-ratelimit-limit-requests": "14400",
            "x-ratelimit-remaining-requests": "14399",
        }
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"api_key": "gsk-test"},
            {"base_url": "https://api.groq.com/openai/v1", "model": "llama-3.1-70b-versatile"},
        )
    assert r.success is True
    assert r.rate_limit is not None
    assert r.rate_limit.remaining == 14399


def test_meta():
    a = GroqProvider()
    assert a.provider_name == "groq"
    assert a.category == ProviderCategory.LLM
    assert a.is_multi_instance is True
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/llm/groq.py
"""Groq LLM provider. Real implementation (OpenAI-compatible + rich rate-limit headers)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class GroqConfig(BaseModel):
    base_url: str = Field(default="https://api.groq.com/openai/v1")
    model: str = Field(default="llama-3.1-70b-versatile")
    timeout_s: float = Field(default=10.0)


class GroqProvider:
    category = ProviderCategory.LLM
    provider_name = "groq"
    is_multi_instance = True
    config_schema = GroqConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/models"
        headers = {"Authorization": f"Bearer {api_key}"}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url, headers=headers) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=rl,
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

- [ ] **Step 3: Run test (4 pass), commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/llm/test_groq.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/llm/groq.py backend/tests/providers/categories/llm/test_groq.py && git commit -m "feat(providers): add Groq LLM provider adapter (real, rate-limit headers verified)"
```

---

### Task 7: AzureOpenAIProvider — api-key header, per-deployment URL, POST probe

**Files:**
- Create: `backend/app/services/providers/categories/llm/azure_openai.py`
- Create: `backend/tests/providers/categories/llm/test_azure_openai.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/llm/test_azure_openai.py`:

```python
"""Tests for the Azure OpenAI LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.azure_openai import AzureOpenAIProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = AzureOpenAIProvider()
    with patch("app.services.providers.categories.llm.azure_openai.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.headers = {}
        session.post = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"api_key": "azure-test-key"},
            {
                "endpoint": "https://myresource.openai.azure.com/openai/deployments/mydeployment",
                "deployment": "mydeployment",
                "api_version": "2024-08-01-preview",
                "model": "gpt-4o",
                "timeout_s": 10.0,
            },
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = AzureOpenAIProvider()
    with patch("app.services.providers.categories.llm.azure_openai.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 401
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="access denied")
        resp.headers = {}
        session.post = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"api_key": "bad"},
            {
                "endpoint": "https://myresource.openai.azure.com/openai/deployments/mydeployment",
                "deployment": "mydeployment",
                "api_version": "2024-08-01-preview",
                "model": "gpt-4o",
                "timeout_s": 10.0,
            },
        )
    assert r.status == ProviderStatus.INACTIVE


@pytest.mark.asyncio
async def test_missing_api_key_returns_error():
    a = AzureOpenAIProvider()
    r = await a.test_connection(
        {},
        {
            "endpoint": "https://myresource.openai.azure.com/openai/deployments/mydeployment",
            "deployment": "mydeployment",
            "api_version": "2024-08-01-preview",
            "model": "gpt-4o",
            "timeout_s": 10.0,
        },
    )
    assert r.success is False
    assert "api_key" in (r.error or "").lower()


def test_meta():
    a = AzureOpenAIProvider()
    assert a.provider_name == "azure_openai"
    assert a.category == ProviderCategory.LLM
    assert a.is_multi_instance is True
```

- [ ] **Step 2: Run test (fail), then implement**

```python
# backend/app/services/providers/categories/llm/azure_openai.py
"""Azure OpenAI LLM provider. Real implementation (per-deployment, api-key header, POST probe)."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class AzureOpenAIConfig(BaseModel):
    endpoint: str  # per-deployment URL e.g. https://myresource.openai.azure.com/openai/deployments/mydeployment
    deployment: str
    api_version: str = "2024-08-01-preview"
    model: str = "gpt-4o"
    timeout_s: float = Field(default=10.0)


class AzureOpenAIProvider:
    category = ProviderCategory.LLM
    provider_name = "azure_openai"
    is_multi_instance = True
    config_schema = AzureOpenAIConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="api_key required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        # Azure OpenAI: api-key header (NOT Bearer), POST chat/completions with 1-token body
        url = f"{cfg.endpoint.rstrip('/')}/chat/completions?api-version={cfg.api_version}"
        headers = {
            "api-key": api_key,
            "Content-Type": "application/json",
        }
        body = {
            "messages": [{"role": "user", "content": "ping"}],
            "max_tokens": 1,
        }
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(url, headers=headers, json=body) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=rl,
                        )
                    body_text = await resp.text()
                    err = f"HTTP {resp.status}: {body_text[:120]}"
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

- [ ] **Step 3: Run test (4 pass), commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/llm/test_azure_openai.py --noconftest -v
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/llm/azure_openai.py backend/tests/providers/categories/llm/test_azure_openai.py && git commit -m "feat(providers): add Azure OpenAI LLM provider adapter (real, per-deployment, api-key header, POST probe)"
```

---

### Task 8: Register the 7 new providers

**Files:**
- Modify: `backend/app/services/providers/categories/llm/__init__.py`

- [ ] **Step 1: Add the 7 new classes to the imports + registration**

Open the file and ensure it has these imports after the existing 3:

```python
from app.services.providers.categories.llm.deepseek import DeepSeekProvider
from app.services.providers.categories.llm.qwen import QwenProvider
from app.services.providers.categories.llm.zhipu import ZhipuProvider
from app.services.providers.categories.llm.moonshot import MoonshotProvider
from app.services.providers.categories.llm.gemini import GeminiProvider
from app.services.providers.categories.llm.groq import GroqProvider
from app.services.providers.categories.llm.azure_openai import AzureOpenAIProvider
```

And ensure the registration block at the bottom lists all 10:

```python
for _cls in (
    OpenAIProvider, AnthropicProvider, OllamaProvider,
    DeepSeekProvider, QwenProvider, ZhipuProvider, MoonshotProvider,
    GeminiProvider, GroqProvider, AzureOpenAIProvider,
):
    registry.register(_cls)
```

- [ ] **Step 2: Smoke test registration**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.services.providers.categories import register_all
register_all()
from app.services.providers.registry import registry
print('LLM:', sorted(registry.list_providers('llm')))
"
```

Expected output:
```
LLM: ['anthropic', 'azure_openai', 'deepseek', 'gemini', 'groq', 'moonshot', 'ollama', 'openai', 'qwen', 'zhipu']
```

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/llm/__init__.py && git commit -m "feat(providers): register 7 new LLM providers (deepseek/qwen/zhipu/moonshot/gemini/groq/azure_openai)"
```

---

### Task 9: Update `docs/integrations/api-audit.md` LLM section

**Files:**
- Modify: `docs/integrations/api-audit.md`

- [ ] **Step 1: Replace the stub line in the LLM section**

Open the file. Find the line:

```
### DeepSeek / Qwen / Zhipu / Moonshot / Gemini / Groq / Azure OpenAI (stubs)
Return `not_implemented`. Real implementations deferred to sub-project 2.
- DeepSeek: https://platform.deepseek.com/api-docs/
- Qwen: https://help.aliyun.com/zh/model-studio/developer-reference/api-reference
- Zhipu: https://open.bigmodel.cn/dev/api
- Moonshot: https://platform.moonshot.cn/docs/api-reference
- Gemini: https://ai.google.dev/gemini-api/docs
- Groq: https://console.groq.com/docs/api-reference
- Azure OpenAI: https://learn.microsoft.com/en-us/azure/ai-services/openai/reference
```

Replace with full entries (one per provider, matching the OpenAI/Anthropic/Ollama format):

```markdown
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
```

- [ ] **Step 2: Verify file is ≥ 200 lines**

```bash
wc -l /Users/novspace/workspace/phosphor-terminal/docs/integrations/api-audit.md
```

Expected: ≥ 200 lines (was 106, now expanded with 7 full entries).

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/integrations/api-audit.md && git commit -m "docs: expand LLM section in api-audit.md (7 real providers)"
```

---

## Self-Review (for the implementer, before claiming done)

- [ ] All 7 new test files exist; all 23 new tests pass
- [ ] Existing 39 unit tests still pass
- [ ] `registry.list_providers('llm')` returns 10 providers
- [ ] `swift build` still passes
- [ ] `docs/integrations/api-audit.md` LLM section is fully expanded (≥ 200 lines)
- [ ] No new dependencies in `requirements.txt`
- [ ] 9 commits in this round (Tasks 1-9)

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-sub-project-2-llm-providers-design.md`
- Plan: `docs/superpowers/plans/2026-06-16-sub-project-2-llm-providers.md`
- Foundation: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md`

**End of plan.**
