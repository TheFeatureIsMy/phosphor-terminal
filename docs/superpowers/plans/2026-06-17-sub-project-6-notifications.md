# Sub-project 6 — Notification Real Implementations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 3 notification adapters (Discord, Email, Webhook) that currently exist as stubs.

**Tech Stack:** Python 3.12 / aiohttp (HTTP) + smtplib (SMTP, stdlib) / pytest. No new deps.

**Spec:** `docs/superpowers/specs/2026-06-17-sub-project-6-notifications-design.md`

**Use venv** at `backend/.venv/bin/python`.

---

## Task 1: DiscordProvider

- [ ] **Step 1: Write `backend/tests/providers/categories/notification/test_discord.py`**:

```python
"""Tests for the Discord notification adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.notification.discord import DiscordProvider


@pytest.mark.asyncio
async def test_204_returns_active():
    a = DiscordProvider()
    with patch("app.services.providers.categories.notification.discord.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 204
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.head = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"webhook_url": "https://discord.com/api/webhooks/123/abc"},
            {"timeout_s": 5.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_404_returns_inactive():
    a = DiscordProvider()
    with patch("app.services.providers.categories.notification.discord.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 404
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.head = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"webhook_url": "https://discord.com/api/webhooks/123/deleted"},
            {"timeout_s": 5.0},
        )
    assert r.status == ProviderStatus.INACTIVE


@pytest.mark.asyncio
async def test_missing_webhook_url_returns_error():
    a = DiscordProvider()
    r = await a.test_connection({}, {"timeout_s": 5.0})
    assert r.success is False
    assert "webhook_url" in (r.error or "")


def test_meta():
    a = DiscordProvider()
    assert a.provider_name == "discord"
    assert a.category == ProviderCategory.NOTIFICATION
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Write `backend/app/services/providers/categories/notification/discord.py`**:

```python
"""Discord notification adapter. Real implementation using webhook URL."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class DiscordConfig(BaseModel):
    timeout_s: float = Field(default=5.0)


class DiscordProvider:
    """Discord notification adapter (webhook model).

    Health check: HEAD the webhook URL. Discord returns 204 if the
    webhook is valid, 404 if it's been deleted.
    """

    category = ProviderCategory.NOTIFICATION
    provider_name = "discord"
    is_multi_instance = False
    config_schema = DiscordConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        webhook_url = credentials.get("webhook_url", "")
        if not webhook_url:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="webhook_url required", latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.head(webhook_url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 204:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    status = (
                        ProviderStatus.INACTIVE
                        if resp.status in (404,) else ProviderStatus.ERROR
                    )
                    return HealthCheckResult(
                        success=False, status=status,
                        latency_ms=latency,
                        error=f"HTTP {resp.status}",
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

- [ ] **Step 3: Run + commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/notification/test_discord.py --noconftest -q 2>&1 | tail -3
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/notification/discord.py backend/tests/providers/categories/notification/test_discord.py && git commit -m "feat(providers): add Discord notification adapter (real, webhook URL)"
```

---

## Task 2: EmailProvider (SMTP)

- [ ] **Step 1: Write `backend/tests/providers/categories/notification/test_email.py`**:

```python
"""Tests for the Email (SMTP) notification adapter."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.notification.email import EmailProvider


@pytest.mark.asyncio
async def test_login_success_returns_active():
    a = EmailProvider()
    fake_smtp = MagicMock()
    with patch("app.services.providers.categories.notification.email.smtplib.SMTP") as SMTP:
        SMTP.return_value.__enter__.return_value = fake_smtp
        r = await a.test_connection(
            {"username": "u", "password": "p"},
            {"host": "smtp.example.com", "port": 587, "use_tls": True, "timeout_s": 5.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE
    assert fake_smtp.login.called


@pytest.mark.asyncio
async def test_login_failure_returns_inactive():
    a = EmailProvider()
    with patch("app.services.providers.categories.notification.email.smtplib.SMTP") as SMTP:
        SMTP.return_value.__enter__.side_effect = Exception("auth failed")
        r = await a.test_connection(
            {"username": "u", "password": "bad"},
            {"host": "smtp.example.com", "port": 587, "use_tls": True, "timeout_s": 5.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = EmailProvider()
    assert a.provider_name == "email"
    assert a.category == ProviderCategory.NOTIFICATION
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Write `backend/app/services/providers/categories/notification/email.py`**:

```python
"""Email (SMTP) notification adapter. Real implementation using smtplib."""
from __future__ import annotations

import smtplib

from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class EmailConfig(BaseModel):
    host: str
    port: int = 587
    use_tls: bool = True
    timeout_s: float = Field(default=5.0)


class EmailProvider:
    """Email (SMTP) notification adapter.

    Health check: open SMTP connection, optionally start TLS, login
    with credentials, quit. Any failure → ERROR or INACTIVE.
    """

    category = ProviderCategory.NOTIFICATION
    provider_name = "email"
    is_multi_instance = False
    config_schema = EmailConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        username = credentials.get("username", "")
        password = credentials.get("password", "")
        cfg = self.config_schema.model_validate(config)
        try:
            with smtplib.SMTP(cfg.host, cfg.port, timeout=cfg.timeout_s) as smtp:
                if cfg.use_tls:
                    smtp.starttls()
                smtp.login(username, password)
            return HealthCheckResult(
                success=True, status=ProviderStatus.ACTIVE,
                latency_ms=None, rate_limit=None,
            )
        except smtplib.SMTPAuthenticationError as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.INACTIVE,
                error=f"SMTP auth failed: {exc}", latency_ms=None,
            )
        except Exception as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error=str(exc)[:200], latency_ms=None,
            )

    async def fetch_rate_limit(self, credentials: dict, config: dict) -> RateLimitInfo | None:
        return None

    def mask_config(self, config: dict) -> dict:
        return dict(config)
```

- [ ] **Step 3: Run + commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/notification/test_email.py --noconftest -q 2>&1 | tail -3
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/notification/email.py backend/tests/providers/categories/notification/test_email.py && git commit -m "feat(providers): add Email (SMTP) notification adapter (real)"
```

---

## Task 3: WebhookProvider (generic HTTP POST)

- [ ] **Step 1: Write `backend/tests/providers/categories/notification/test_webhook.py`**:

```python
"""Tests for the Webhook notification adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.notification.webhook import WebhookProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = WebhookProvider()
    with patch("app.services.providers.categories.notification.webhook.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.post = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"auth_header": "Bearer xyz"},
            {"url": "https://example.com/webhook", "timeout_s": 5.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = WebhookProvider()
    with patch("app.services.providers.categories.notification.webhook.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 500
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="server error")
        session.post = MagicMock(return_value=resp)
        r = await a.test_connection(
            {},
            {"url": "https://example.com/webhook", "timeout_s": 5.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = WebhookProvider()
    assert a.provider_name == "webhook"
    assert a.category == ProviderCategory.NOTIFICATION
    assert a.is_multi_instance is False
```

- [ ] **Step 2: Write `backend/app/services/providers/categories/notification/webhook.py`**:

```python
"""Generic Webhook notification adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class WebhookConfig(BaseModel):
    url: str
    timeout_s: float = Field(default=5.0)


class WebhookProvider:
    """Generic webhook notification adapter.

    Health check: POST {"ping": true} to the configured URL. Expect 2xx.
    Optional auth_header credential (e.g., "Bearer xyz").
    """

    category = ProviderCategory.NOTIFICATION
    provider_name = "webhook"
    is_multi_instance = False
    config_schema = WebhookConfig

    async def test_connection(self, credentials: dict, config: dict) -> HealthCheckResult:
        cfg = self.config_schema.model_validate(config)
        headers = {"Content-Type": "application/json"}
        auth_header = credentials.get("auth_header")
        if auth_header:
            headers["Authorization"] = auth_header
        body = {"ping": True}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(cfg.url, json=body, headers=headers) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if 200 <= resp.status < 300:
                        return HealthCheckResult(
                            success=True, status=ProviderStatus.ACTIVE,
                            latency_ms=latency, rate_limit=None,
                        )
                    return HealthCheckResult(
                        success=False, status=ProviderStatus.ERROR,
                        latency_ms=latency,
                        error=f"HTTP {resp.status}",
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

- [ ] **Step 3: Run + commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -m pytest tests/providers/categories/notification/test_webhook.py --noconftest -q 2>&1 | tail -3
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/notification/webhook.py backend/tests/providers/categories/notification/test_webhook.py && git commit -m "feat(providers): add Webhook notification adapter (real, generic HTTP POST)"
```

---

## Task 4: Register 3 new providers + smoke test

- [ ] **Step 1: Replace `backend/app/services/providers/categories/notification/__init__.py`** with:

```python
"""Notification provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.notification.telegram import TelegramProvider
from app.services.providers.categories.notification.discord import DiscordProvider
from app.services.providers.categories.notification.email import EmailProvider
from app.services.providers.categories.notification.webhook import WebhookProvider


for _cls in (TelegramProvider, DiscordProvider, EmailProvider, WebhookProvider):
    registry.register(_cls)
```

- [ ] **Step 2: Smoke test**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && .venv/bin/python -c "
from app.services.providers.categories import register_all
register_all()
from app.services.providers.registry import registry
print('notification:', sorted(registry.list_providers('notification')))
"
```

Expected: `['discord', 'email', 'telegram', 'webhook']` (4 notification).

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/notification/__init__.py && git commit -m "feat(providers): register 3 new notification providers (discord/email/webhook)"
```

---

## Task 5: Update `docs/integrations/api-audit.md` Notification section

- [ ] **Step 1: Find the stub line**

```bash
cd /Users/novspace/workspace/phosphor-terminal && grep -n "Discord / Email / Webhook" docs/integrations/api-audit.md
```

Find the line beginning `### Discord / Email / Webhook (stubs)`.

- [ ] **Step 2: Replace that block with 3 full entries** (Discord/Email/Webhook), using the same field shape as the existing Telegram entry. Reference the spec for content.

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/integrations/api-audit.md && git commit -m "docs: expand notification section in api-audit.md (3 real providers)"
```

---

## Acceptance Criteria

- 3 new adapter files + 3 new test files
- All 9 new tests pass
- `registry.list_providers('notification')` returns 4
- 5 commits in this round

**End of plan.**
