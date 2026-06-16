# Provider Adapter Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the unified Provider Adapter foundation: 8-category abstraction, single `provider_configs` table with Pydantic discriminated union, encrypted credentials, native asyncio health scheduler, admin API, and one-time migration of all existing LLM/data-source/telegram code paths into the new framework. 6 real + 12 stub providers. Dev phase — no compatibility shims.

**Architecture:** New `backend/app/services/providers/` package holds the ProviderAdapter Protocol, registry, config service, health service, and scheduler. Single `provider_configs` SQLAlchemy table; Pydantic discriminated union (`ProviderConfigPayload`) guards category-specific shape. Existing `ai_provider_configs` and `/tmp/pulsedesk_datasources_state.json` are dropped. Native asyncio scheduler (no new deps) ticks every 60s on enabled providers. iOS plumbing-only URL changes; no visual UI redesign.

**Tech Stack:** Python 3.11 / FastAPI 0.115 / SQLAlchemy 2.0 / Pydantic v2 / aiohttp / Fernet (existing) / pytest + pytest-asyncio. Swift 6.2 / SwiftUI (iOS plumbing only).

**Spec:** `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md`

---

## File Map

### New (backend) — `backend/app/`
- `services/providers/__init__.py` — package init
- `services/providers/base.py` — `ProviderAdapter` Protocol, `ProviderCategory`, `ProviderStatus`, `CredentialStatus`, `ProviderStubBase` (DRY stub helper)
- `services/providers/runtime.py` — `RateLimitInfo`, `HealthCheckResult`, `RateLimitParser`
- `services/providers/crypto.py` — `ProviderSecretCodec` thin wrapper over `CryptoService`
- `services/providers/registry.py` — `ProviderRegistry` singleton
- `services/providers/config_service.py` — `ProviderConfigService`, `DuplicateProviderError`, `ProviderNotFoundError`
- `services/providers/health_service.py` — `ProviderHealthService`
- `services/providers/scheduler.py` — `ProviderHealthTickPolicy`, `ProviderHealthScheduler`
- `services/providers/categories/__init__.py` — auto-imports all category sub-packages
- `services/providers/categories/llm/__init__.py` — registers LLM adapters
- `services/providers/categories/llm/{openai,anthropic,ollama}.py` — real adapters
- `services/providers/categories/llm/{deepseek,qwen,zhipu,moonshot,gemini,groq,azure_openai}.py` — stubs (1-line each via base class)
- `services/providers/categories/cex/__init__.py` — registers CEX adapters
- `services/providers/categories/cex/{binance,freqtrade}.py` — real adapters
- `services/providers/categories/cex/{okx,bybit,bitget}.py` — stubs
- `services/providers/categories/dex/__init__.py`
- `services/providers/categories/dex/{gmx,hyperliquid,dydx}.py` — stubs
- `services/providers/categories/notification/__init__.py`
- `services/providers/categories/notification/telegram.py` — real adapter
- `services/providers/categories/notification/{discord,email,webhook}.py` — stubs
- `services/providers/categories/market_data/__init__.py`
- `services/providers/categories/market_data/{kline,orderbook,funding,oi}.py` — stubs
- `services/providers/categories/onchain/__init__.py`
- `services/providers/categories/onchain/{glassnode,cryptoquant,whale_alert}.py` — stubs
- `services/providers/categories/social/__init__.py`
- `services/providers/categories/social/{cryptocompare_social,lunarcrush}.py` — stubs
- `services/providers/categories/news/__init__.py`
- `services/providers/categories/news/{cryptocompare_news,cryptopanic}.py` — stubs
- `models/provider_config.py` — `ProviderConfig`, `ProviderAuditLog` SQLAlchemy
- `schemas/provider_config.py` — Pydantic discriminated union + view model
- `routers/admin/providers.py` — admin API endpoints
- `routers/admin/providers_audit.py` — audit log endpoints
- `routers/admin/__init__.py` — admin router init
- `alembic/versions/2026_06_16_xxxx_provider_foundation.py` — migration
- `tests/providers/__init__.py`
- `tests/providers/test_base.py`
- `tests/providers/test_runtime.py`
- `tests/providers/test_registry.py`
- `tests/providers/test_config_service.py`
- `tests/providers/test_health_service.py`
- `tests/providers/test_scheduler.py`
- `tests/providers/categories/__init__.py`
- `tests/providers/categories/test_llm_openai.py`
- `tests/providers/categories/test_llm_anthropic.py`
- `tests/providers/categories/test_llm_ollama.py`
- `tests/providers/categories/test_cex_binance.py`
- `tests/providers/categories/test_cex_freqtrade.py`
- `tests/providers/categories/test_notification_telegram.py`
- `tests/integration/test_admin_providers_api.py`
- `docs/integrations/api-audit.md`
- `docs/settings/configuration-model.md`
- `docs/backend/api-contracts.md`
- `docs/database/schema-notes.md`

### Modified (backend)
- `app/config.py` — add `provider_health_*` settings
- `app/models/ai_provider.py` — remove `AIProviderConfig`; keep `AIUsageLog` with new `provider_config_id` FK
- `app/main.py` — register admin/providers router; start scheduler in lifespan
- `app/routers/ai_providers.py` — drop LLM CRUD/test/usage endpoints; keep ML model status + routing/privacy rules
- `app/services/llm_service.py` — slim down to a priority-based selector using registry
- `app/services/telegram_notifier.py` — keep thin wrapper that pulls creds from `provider_configs`
- `app/services/dependency_checker.py` — DB-first; env vars as fallback
- `app/database.py` — register new models

### Deleted (backend)
- `app/services/data_source_manager.py`
- `app/routers/data_source_bff.py`
- `/tmp/pulsedesk_datasources_state.json` (in repo: `backend/data/.gitkeep` only)

### Modified (iOS plumbing only — no visual UI)
- `macos-app/AlphaLoop/Services/APIAIProviders.swift` — point at new endpoints
- `macos-app/AlphaLoop/Services/APIDataSources.swift` — point at new endpoint
- `macos-app/AlphaLoop/Services/APINotifications.swift` — telegram test uses new endpoint

### Modified (docs)
- `CLAUDE.md` — add Backend Architecture section
- `README.md` — mention foundation

---

## PR 1: Bedrock

### Task 1.1: Settings additions for health scheduler

**Files:**
- Modify: `backend/app/config.py`

- [ ] **Step 1: Add the new settings fields**

Edit `backend/app/config.py` — add these 3 fields inside the `Settings` class (after `rate_limit_burst`):

```python
    # Provider health scheduler (sub-project 1 of provider foundation)
    provider_health_interval_s: int = 60
    provider_health_batch_size: int = 10
    provider_health_enabled: bool = True
```

- [ ] **Step 2: Verify settings load**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -c "from app.config import settings; print(settings.provider_health_interval_s, settings.provider_health_batch_size, settings.provider_health_enabled)"
```

Expected: `60 10 True`

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/config.py && git commit -m "feat(providers): add health scheduler settings"
```

---

### Task 1.2: SQLAlchemy model — `ProviderConfig` + `ProviderAuditLog`

**Files:**
- Create: `backend/app/models/provider_config.py`

- [ ] **Step 1: Create the model file**

Write `backend/app/models/provider_config.py`:

```python
"""Provider configuration persistence models.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §6.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
)

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ProviderConfig(Base):
    __tablename__ = "provider_configs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    # Identity
    category = Column(String, nullable=False, index=True)
    provider_name = Column(String, nullable=False, index=True)
    instance_name = Column(String, nullable=True)
    # Non-sensitive configuration
    config = Column(JSON, nullable=False, default=dict)
    # Encrypted credentials
    credentials_ct = Column(Text, nullable=True)
    credentials_fields = Column(JSON, nullable=True)
    # Status
    enabled = Column(Boolean, nullable=False, default=True)
    is_active = Column(Boolean, nullable=False, default=False)
    priority = Column(Integer, nullable=False, default=0)
    status = Column(String, nullable=False, default="unknown")
    credential_status = Column(String, nullable=False, default="missing")
    last_sync_at = Column(DateTime, nullable=True)
    last_error = Column(String, nullable=True)
    latency_ms = Column(Integer, nullable=True)
    rate_limit_remaining = Column(Integer, nullable=True)
    rate_limit_reset_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=_utcnow)
    updated_at = Column(DateTime, nullable=False, default=_utcnow, onupdate=_utcnow)

    __table_args__ = (
        CheckConstraint(
            "(category = 'llm' AND instance_name IS NOT NULL) OR "
            "(category != 'llm' AND instance_name IS NULL)",
            name="ck_instance_name_by_category",
        ),
        Index("ix_provider_config_cat_name", "category", "provider_name"),
        Index("ix_provider_config_enabled", "enabled"),
    )


class ProviderAuditLog(Base):
    __tablename__ = "provider_audit_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    provider_id = Column(
        Integer,
        ForeignKey("provider_configs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    action = Column(String, nullable=False)
    actor = Column(String, nullable=True)
    before_hash = Column(String, nullable=True)
    after_hash = Column(String, nullable=True)
    ip = Column(String, nullable=True)
    created_at = Column(DateTime, nullable=False, default=_utcnow, index=True)
```

- [ ] **Step 2: Smoke-import the model**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -c "from app.models.provider_config import ProviderConfig, ProviderAuditLog; print(ProviderConfig.__tablename__, ProviderAuditLog.__tablename__)"
```

Expected: `provider_configs provider_audit_logs`

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/models/provider_config.py && git commit -m "feat(providers): add ProviderConfig and ProviderAuditLog models"
```

---

### Task 1.3: Pydantic schemas — discriminated union + view model

**Files:**
- Create: `backend/app/schemas/provider_config.py`

- [ ] **Step 1: Create the schema file**

Write `backend/app/schemas/provider_config.py`:

```python
"""Pydantic schemas for provider configuration.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §6.2-6.3.
"""
from __future__ import annotations

from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field


class ProviderConfigBase(BaseModel):
    category: Literal[
        "llm", "cex", "dex", "notification",
        "market_data", "onchain", "social", "news",
    ]
    provider_name: str = Field(min_length=1, max_length=64)
    instance_name: str | None = Field(default=None, min_length=1, max_length=64)
    enabled: bool = True
    priority: int = Field(default=0, ge=0, le=10_000)
    config: dict = Field(default_factory=dict)
    # Plaintext credentials; encrypted by the service layer before storage.
    credentials: dict | None = None


class LLMConfig(ProviderConfigBase):
    category: Literal["llm"]
    instance_name: str  # required for LLM
    credentials: dict | None = None  # {api_key: str}


class CEXConfig(ProviderConfigBase):
    category: Literal["cex"]
    credentials: dict | None = None  # {api_key, api_secret, passphrase?}


class DeXConfig(ProviderConfigBase):
    category: Literal["dex"]
    credentials: dict | None = None  # {wallet_address, signature_provider}


class NotificationConfig(ProviderConfigBase):
    category: Literal["notification"]
    credentials: dict | None = None  # {bot_token, chat_id} for telegram


class MarketDataConfig(ProviderConfigBase):
    category: Literal["market_data"]
    credentials: dict | None = None  # {api_key}


class OnchainConfig(ProviderConfigBase):
    category: Literal["onchain"]
    credentials: dict | None = None  # {api_key}


class SocialConfig(ProviderConfigBase):
    category: Literal["social"]
    credentials: dict | None = None  # {api_key}


class NewsConfig(ProviderConfigBase):
    category: Literal["news"]
    credentials: dict | None = None  # {api_key}


ProviderConfigPayload = Annotated[
    LLMConfig | CEXConfig | DeXConfig | NotificationConfig
    | MarketDataConfig | OnchainConfig | SocialConfig | NewsConfig,
    Field(discriminator="category"),
]


class ProviderConfigView(BaseModel):
    """Read-side view model. Never contains plaintext credentials."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    category: str
    provider_name: str
    instance_name: str | None
    enabled: bool
    is_active: bool
    priority: int
    status: str
    credential_status: str
    credential_fields: list[str]
    last_sync_at: datetime | None
    last_error: str | None
    latency_ms: int | None
    rate_limit_remaining: int | None
    rate_limit_reset_at: datetime | None
    config: dict
    updated_at: datetime


class HealthCheckResultSchema(BaseModel):
    success: bool
    status: str
    latency_ms: int | None
    error: str | None
    rate_limit: dict | None
    checked_at: datetime


class ProviderTestRequest(BaseModel):
    category: Literal[
        "llm", "cex", "dex", "notification",
        "market_data", "onchain", "social", "news",
    ]
    provider_name: str = Field(min_length=1, max_length=64)
    instance_name: str | None = None
    config: dict = Field(default_factory=dict)
    credentials: dict | None = None


class ProviderSummaryView(BaseModel):
    by_category: dict[str, int]
    total_active: int
    total_error: int
    total_disabled: int
    total_configured: int
    total: int
    checked_at: datetime
```

- [ ] **Step 2: Smoke-import + discriminated union validation**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -c "
from app.schemas.provider_config import LLMConfig, CEXConfig, ProviderConfigPayload
import pydantic
# LLM requires instance_name
try:
    LLMConfig(category='llm', provider_name='openai')
    print('FAIL: should have raised')
except pydantic.ValidationError as e:
    print('OK: LLM without instance_name raises:', str(e).splitlines()[1].strip())
# Non-LLM rejects instance_name via service layer; here schema accepts it but service will reject
llm = LLMConfig(category='llm', provider_name='openai', instance_name='dev', api_key='sk-xxx')
print('OK:', llm.provider_name, llm.instance_name)
"
```

Expected:
```
OK: LLM without instance_name raises: ...
OK: openai dev
```

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/schemas/provider_config.py && git commit -m "feat(providers): add Pydantic discriminated union + view model"
```

---

### Task 1.4: `base.py` — Protocol, enums, DTOs, stub base

**Files:**
- Create: `backend/app/services/providers/base.py`
- Create: `backend/tests/providers/__init__.py`
- Create: `backend/tests/providers/test_base.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/test_base.py`:

```python
"""Tests for the ProviderAdapter Protocol and DTOs."""
from __future__ import annotations

import pytest
from pydantic import BaseModel, ValidationError

from app.services.providers.base import (
    CredentialStatus,
    HealthCheckResult,
    ProviderCategory,
    ProviderStatus,
    ProviderStubBase,
)


def test_provider_category_values():
    assert ProviderCategory.LLM.value == "llm"
    assert ProviderCategory.CEX.value == "cex"
    assert len(list(ProviderCategory)) == 8


def test_health_check_result_default_error_truncation():
    big_error = "x" * 500
    # The shape is up to the adapter; result is just a DTO
    r = HealthCheckResult(
        success=False, status=ProviderStatus.ERROR,
        latency_ms=None, error=big_error, rate_limit=None,
        checked_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
    )
    assert r.error == big_error  # no automatic truncation in DTO


def test_stub_base_returns_not_implemented():
    class MyStub(ProviderStubBase):
        category = ProviderCategory.NEWS
        provider_name = "test_news"
        config_schema = BaseModel

    import asyncio
    result = asyncio.run(MyStub().test_connection({}, {}))
    assert result.success is False
    assert result.status == ProviderStatus.ERROR
    assert result.error == "not_implemented"


def test_stub_base_is_multi_instance_defaults_false():
    class MyStub(ProviderStubBase):
        category = ProviderCategory.CEX
        provider_name = "test_cex"
        config_schema = BaseModel

    assert MyStub.is_multi_instance is False
```

- [ ] **Step 2: Run the test to confirm it fails**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_base.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.providers.base'`

- [ ] **Step 3: Implement `base.py`**

Write `backend/app/services/providers/base.py`:

```python
"""ProviderAdapter Protocol, enums, DTOs, and stub base class.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §7.1.
"""
from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Any, Protocol, runtime_checkable

from pydantic import BaseModel, Field


class ProviderCategory(str, Enum):
    LLM = "llm"
    CEX = "cex"
    DEX = "dex"
    NOTIFICATION = "notification"
    MARKET_DATA = "market_data"
    ONCHAIN = "onchain"
    SOCIAL = "social"
    NEWS = "news"


class ProviderStatus(str, Enum):
    UNKNOWN = "unknown"
    ACTIVE = "active"
    INACTIVE = "inactive"
    ERROR = "error"
    RATE_LIMITED = "rate_limited"
    DISABLED = "disabled"


class CredentialStatus(str, Enum):
    MISSING = "missing"
    CONFIGURED = "configured"
    EXPIRED = "expired"
    INVALID = "invalid"


class RateLimitInfo(BaseModel):
    remaining: int | None = None
    limit: int | None = None
    reset_at: datetime | None = None
    retry_after_s: int | None = None
    source: str = ""


class HealthCheckResult(BaseModel):
    success: bool
    status: ProviderStatus
    latency_ms: int | None = None
    error: str | None = None
    rate_limit: RateLimitInfo | None = None
    checked_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


@runtime_checkable
class ProviderAdapter(Protocol):
    """Every provider must implement this Protocol."""

    category: ProviderCategory
    provider_name: str
    is_multi_instance: bool
    config_schema: type[BaseModel]

    async def test_connection(
        self, credentials: dict, config: dict
    ) -> HealthCheckResult: ...

    async def fetch_rate_limit(
        self, credentials: dict, config: dict
    ) -> RateLimitInfo | None: ...

    def mask_config(self, config: dict) -> dict: ...


class ProviderStubBase:
    """DRY base for stub providers. Returns not_implemented on test."""

    category: ProviderCategory
    provider_name: str
    is_multi_instance: bool = False
    config_schema: type[BaseModel] = BaseModel

    async def test_connection(
        self, credentials: dict, config: dict
    ) -> HealthCheckResult:
        return HealthCheckResult(
            success=False,
            status=ProviderStatus.ERROR,
            error="not_implemented",
        )

    async def fetch_rate_limit(
        self, credentials: dict, config: dict
    ) -> RateLimitInfo | None:
        return None

    def mask_config(self, config: dict) -> dict:
        return dict(config)
```

- [ ] **Step 4: Run the test to confirm it passes**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_base.py -v
```

Expected: 4 tests passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/base.py backend/tests/providers/ && git commit -m "feat(providers): add ProviderAdapter Protocol and ProviderStubBase"
```

---

### Task 1.5: `runtime.py` — RateLimitParser

**Files:**
- Create: `backend/app/services/providers/runtime.py`
- Create: `backend/tests/providers/test_runtime.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/test_runtime.py`:

```python
"""Tests for the RateLimitParser."""
from __future__ import annotations

from datetime import datetime, timezone

from app.services.providers.base import RateLimitInfo
from app.services.providers.runtime import RateLimitParser


def test_parse_standard_ratelimit_headers():
    headers = {
        "X-RateLimit-Remaining": "42",
        "X-RateLimit-Limit": "100",
        "X-RateLimit-Reset": "1700000000",
    }
    info = RateLimitParser.parse(headers)
    assert info is not None
    assert info.remaining == 42
    assert info.limit == 100
    assert info.reset_at is not None
    assert info.source.startswith("header:")


def test_parse_binance_weight_header():
    headers = {"X-MBX-USED-WEIGHT-1M": "950"}
    info = RateLimitParser.parse(headers)
    assert info is not None
    assert info.remaining == 6000 - 950  # default Binance spot weight capacity
    assert "X-MBX-USED-WEIGHT-1M" in info.source


def test_parse_retry_after_seconds():
    headers = {"Retry-After": "30"}
    info = RateLimitParser.parse(headers)
    assert info is not None
    assert info.retry_after_s == 30


def test_parse_unknown_provider_returns_none():
    assert RateLimitParser.parse({}) is None
    assert RateLimitParser.parse({"Content-Type": "application/json"}) is None


def test_parse_case_insensitive():
    headers = {"x-ratelimit-remaining": "5"}
    info = RateLimitParser.parse(headers)
    assert info is not None
    assert info.remaining == 5
```

- [ ] **Step 2: Run test to confirm it fails**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_runtime.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.providers.runtime'`

- [ ] **Step 3: Implement `runtime.py`**

Write `backend/app/services/providers/runtime.py`:

```python
"""Rate-limit header parser.

Sub-project 1 of the Provider Adapter Foundation.
"""
from __future__ import annotations

from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

from app.services.providers.base import RateLimitInfo


class RateLimitParser:
    """Parses common rate-limit HTTP headers into a RateLimitInfo.

    Headers covered (case-insensitive):
    - X-RateLimit-Remaining / X-RateLimit-Limit / X-RateLimit-Reset
    - X-MBX-USED-WEIGHT-1M (Binance)
    - X-Bapi-Limit-Status / X-Bapi-Limit (Binance public v3)
    - Coinglass-RateLimit-Remaining
    - Retry-After (HTTP standard, seconds or HTTP-date)
    """

    # Binance spot default weight capacity per minute (informational default)
    BINANCE_SPOT_WEIGHT_CAPACITY_1M = 6000

    @classmethod
    def parse(cls, headers: dict[str, str]) -> RateLimitInfo | None:
        # Normalize keys to lowercase for lookup
        lower = {k.lower(): v for k, v in headers.items() if isinstance(v, str)}

        remaining: int | None = None
        limit: int | None = None
        reset_at: datetime | None = None
        retry_after_s: int | None = None
        source: str = ""

        # Standard X-RateLimit-* family
        if "x-ratelimit-remaining" in lower:
            remaining = int(lower["x-ratelimit-remaining"])
            source = "header:x-ratelimit-remaining"
        if "x-ratelimit-limit" in lower:
            limit = int(lower["x-ratelimit-limit"])
        if "x-ratelimit-reset" in lower:
            reset_at = cls._parse_reset(lower["x-ratelimit-reset"])

        # Binance used weight (subtract from capacity)
        if "x-mbx-used-weight-1m" in lower:
            used = int(lower["x-mbx-used-weight-1m"])
            capacity = cls.BINANCE_SPOT_WEIGHT_CAPACITY_1M
            remaining = max(0, capacity - used)
            limit = capacity
            source = "header:x-mbx-used-weight-1m"

        # Binance v3 headers
        if "x-bapi-limit-status" in lower:
            remaining = int(lower["x-bapi-limit-status"])
            source = "header:x-bapi-limit-status"
        if "x-bapi-limit" in lower:
            limit = int(lower["x-bapi-limit"])

        # Coinglass-style
        if "coinglass-ratelimit-remaining" in lower:
            remaining = int(lower["coinglass-ratelimit-remaining"])
            source = "header:coinglass-ratelimit-remaining"

        # Retry-After (HTTP standard)
        if "retry-after" in lower:
            retry_after_s = cls._parse_retry_after(lower["retry-after"])
            # If we have nothing else, treat Retry-After alone as a signal
            if not source:
                source = "header:retry-after"

        if not source:
            return None

        return RateLimitInfo(
            remaining=remaining,
            limit=limit,
            reset_at=reset_at,
            retry_after_s=retry_after_s,
            source=source,
        )

    @staticmethod
    def _parse_reset(value: str) -> datetime | None:
        # Try Unix timestamp first, then HTTP-date
        try:
            ts = int(value)
            return datetime.fromtimestamp(ts, tz=timezone.utc)
        except (ValueError, TypeError):
            pass
        try:
            dt = parsedate_to_datetime(value)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _parse_retry_after(value: str) -> int | None:
        try:
            return int(value)
        except (ValueError, TypeError):
            pass
        try:
            dt = parsedate_to_datetime(value)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            delta = dt - datetime.now(timezone.utc)
            return max(0, int(delta.total_seconds()))
        except (TypeError, ValueError):
            return None
```

- [ ] **Step 4: Run test to confirm it passes**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_runtime.py -v
```

Expected: 5 tests passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/runtime.py backend/tests/providers/test_runtime.py && git commit -m "feat(providers): add RateLimitParser for known header families"
```

---

### Task 1.6: `crypto.py` — ProviderSecretCodec

**Files:**
- Create: `backend/app/services/providers/crypto.py`
- Create: `backend/tests/providers/test_crypto_codec.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/test_crypto_codec.py`:

```python
"""Tests for ProviderSecretCodec."""
from __future__ import annotations

import json
import os

import pytest


@pytest.fixture
def fernet_key(monkeypatch):
    # Generate a fresh Fernet key for the test
    from cryptography.fernet import Fernet
    key = Fernet.generate_key().decode()
    monkeypatch.setenv("PULSEDESK_ENCRYPTION_KEY", key)
    yield key


def test_codec_encrypts_credentials_dict(fernet_key):
    # Reset cached service module
    import importlib
    from app.services import crypto_service
    importlib.reload(crypto_service)
    from app.services.providers.crypto import ProviderSecretCodec
    from app.services.crypto_service import CryptoService

    crypto = CryptoService()
    codec = ProviderSecretCodec(crypto=crypto)

    creds = {"api_key": "sk-abc-123", "api_secret": "very-secret"}
    ciphertext = codec.encrypt_dict(creds)
    assert ciphertext != json.dumps(creds)
    assert "sk-abc-123" not in ciphertext

    decoded = codec.decrypt_dict(ciphertext)
    assert decoded == creds


def test_codec_extracts_field_names():
    from app.services.providers.crypto import ProviderSecretCodec
    from app.services.crypto_service import CryptoService

    codec = ProviderSecretCodec(crypto=CryptoService())
    creds = {"api_key": "x", "api_secret": "y", "passphrase": "z"}
    assert codec.field_names(creds) == ["api_key", "api_secret", "passphrase"]


def test_codec_handles_none_input():
    from app.services.providers.crypto import ProviderSecretCodec
    from app.services.crypto_service import CryptoService

    codec = ProviderSecretCodec(crypto=CryptoService())
    assert codec.encrypt_dict(None) is None
    assert codec.decrypt_dict(None) is None
    assert codec.field_names(None) == []
```

- [ ] **Step 2: Run test to confirm it fails**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_crypto_codec.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.providers.crypto'`

- [ ] **Step 3: Implement `crypto.py`**

Write `backend/app/services/providers/crypto.py`:

```python
"""Thin wrapper over CryptoService for provider credentials.

Provider credentials are stored as Fernet-encrypted JSON of the dict
{api_key, api_secret, ...}. The field names (top-level keys) are stored
separately in plain text so the UI can show "API key configured" without
ever seeing the value.
"""
from __future__ import annotations

import json

from app.services.crypto_service import CryptoService


class ProviderSecretCodec:
    def __init__(self, crypto: CryptoService | None = None) -> None:
        self._crypto = crypto or CryptoService()

    def encrypt_dict(self, credentials: dict | None) -> str | None:
        if credentials is None:
            return None
        if not isinstance(credentials, dict):
            raise TypeError("credentials must be a dict or None")
        payload = json.dumps(credentials, sort_keys=True, ensure_ascii=False)
        return self._crypto.encrypt(payload)

    def decrypt_dict(self, ciphertext: str | None) -> dict | None:
        if ciphertext is None:
            return None
        plaintext = self._crypto.decrypt(ciphertext)
        try:
            return json.loads(plaintext)
        except (json.JSONDecodeError, TypeError):
            return None

    @staticmethod
    def field_names(credentials: dict | None) -> list[str]:
        if not credentials or not isinstance(credentials, dict):
            return []
        return sorted(credentials.keys())
```

- [ ] **Step 4: Run test to confirm it passes**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_crypto_codec.py -v
```

Expected: 3 tests passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/crypto.py backend/tests/providers/test_crypto_codec.py && git commit -m "feat(providers): add ProviderSecretCodec over CryptoService"
```

---

### Task 1.7: `registry.py` — ProviderRegistry

**Files:**
- Create: `backend/app/services/providers/registry.py`
- Create: `backend/tests/providers/test_registry.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/test_registry.py`:

```python
"""Tests for the ProviderRegistry."""
from __future__ import annotations

from pydantic import BaseModel

from app.services.providers.base import (
    ProviderCategory,
    ProviderStubBase,
)
from app.services.providers.registry import (
    DuplicateProviderError,
    ProviderRegistry,
    registry,
)


class _FakeLLM(ProviderStubBase):
    category = ProviderCategory.LLM
    provider_name = "fake_llm"
    is_multi_instance = True
    config_schema = BaseModel


class _FakeCEX(ProviderStubBase):
    category = ProviderCategory.CEX
    provider_name = "fake_cex"
    config_schema = BaseModel


def test_register_and_get():
    reg = ProviderRegistry()
    reg.register(_FakeLLM)
    instance = reg.get(ProviderCategory.LLM, "fake_llm")
    assert instance.provider_name == "fake_llm"
    assert instance.is_multi_instance is True


def test_duplicate_register_raises():
    reg = ProviderRegistry()
    reg.register(_FakeLLM)
    try:
        reg.register(_FakeLLM)
    except DuplicateProviderError:
        pass
    else:
        raise AssertionError("expected DuplicateProviderError")


def test_get_unknown_provider_raises():
    reg = ProviderRegistry()
    try:
        reg.get(ProviderCategory.NEWS, "nope")
    except KeyError:
        pass
    else:
        raise AssertionError("expected KeyError")


def test_list_by_category():
    reg = ProviderRegistry()
    reg.register(_FakeLLM)
    reg.register(_FakeCEX)
    llms = reg.list_providers(ProviderCategory.LLM)
    assert "fake_llm" in llms


def test_validate_flags_match_category_raises():
    """An LLM adapter with is_multi_instance=False should fail validation."""
    class BadLLM(ProviderStubBase):
        category = ProviderCategory.LLM
        provider_name = "bad_llm"
        is_multi_instance = False  # LLM must be multi-instance
        config_schema = BaseModel

    reg = ProviderRegistry()
    try:
        reg.register(BadLLM)
    except ValueError:
        pass
    else:
        raise AssertionError("expected ValueError for LLM with is_multi_instance=False")


def test_validate_non_llm_multi_instance_raises():
    class BadCEX(ProviderStubBase):
        category = ProviderCategory.CEX
        provider_name = "bad_cex"
        is_multi_instance = True  # Non-LLM must be single-instance
        config_schema = BaseModel

    reg = ProviderRegistry()
    try:
        reg.register(BadCEX)
    except ValueError:
        pass
    else:
        raise AssertionError("expected ValueError for non-LLM with is_multi_instance=True")
```

- [ ] **Step 2: Run test to confirm it fails**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_registry.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.providers.registry'`

- [ ] **Step 3: Implement `registry.py`**

Write `backend/app/services/providers/registry.py`:

```python
"""ProviderRegistry: in-process registry of ProviderAdapter classes.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §5.3.
"""
from __future__ import annotations

from typing import Type

from app.services.providers.base import ProviderAdapter, ProviderCategory


class DuplicateProviderError(ValueError):
    """Raised when registering a (category, provider_name) twice."""


class ProviderRegistry:
    """In-process registry of ProviderAdapter classes.

    Adapters register at import time. The registry validates that
    `is_multi_instance` matches the category rules (LLM=True; others=False).
    """

    def __init__(self) -> None:
        self._adapters: dict[tuple[ProviderCategory, str], type[ProviderAdapter]] = {}

    def register(self, adapter_class: Type[ProviderAdapter]) -> None:
        if not (hasattr(adapter_class, "category") and hasattr(adapter_class, "provider_name")):
            raise ValueError(
                f"{adapter_class.__name__} must declare class attributes 'category' and 'provider_name'"
            )
        category = adapter_class.category
        provider_name = adapter_class.provider_name
        is_multi = getattr(adapter_class, "is_multi_instance", False)
        # Validation: LLM must be multi-instance, others must be single-instance
        if category == ProviderCategory.LLM and not is_multi:
            raise ValueError(
                f"Provider {category.value}/{provider_name} has is_multi_instance=False; "
                "LLM adapters must be multi-instance."
            )
        if category != ProviderCategory.LLM and is_multi:
            raise ValueError(
                f"Provider {category.value}/{provider_name} has is_multi_instance=True; "
                "only LLM adapters may be multi-instance."
            )
        key = (category, provider_name)
        if key in self._adapters:
            raise DuplicateProviderError(
                f"Provider already registered: {category.value}/{provider_name}"
            )
        self._adapters[key] = adapter_class

    def get(self, category: ProviderCategory, provider_name: str) -> ProviderAdapter:
        key = (category, provider_name)
        if key not in self._adapters:
            raise KeyError(
                f"Unknown provider: {category.value}/{provider_name}"
            )
        return self._adapters[key]()

    def list_providers(self, category: ProviderCategory | None = None) -> list[str]:
        if category is None:
            return [name for (_cat, name) in self._adapters]
        return [
            name for (cat, name) in self._adapters if cat == category
        ]

    def has(self, category: ProviderCategory, provider_name: str) -> bool:
        return (category, provider_name) in self._adapters


# Process-wide singleton; categories package populates this on import.
registry = ProviderRegistry()
```

- [ ] **Step 4: Run test to confirm it passes**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_registry.py -v
```

Expected: 6 tests passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/registry.py backend/tests/providers/test_registry.py && git commit -m "feat(providers): add ProviderRegistry with category/multi-instance validation"
```

---

### Task 1.8: `config_service.py` — CRUD + uniqueness

**Files:**
- Create: `backend/app/services/providers/config_service.py`
- Create: `backend/tests/providers/test_config_service.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/test_config_service.py`:

```python
"""Tests for ProviderConfigService — CRUD, encryption, uniqueness."""
from __future__ import annotations

import json

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models.provider_config import ProviderConfig
from app.services.providers.base import ProviderCategory
from app.services.providers.config_service import (
    DuplicateProviderError,
    ProviderConfigService,
)


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    s = Session()
    yield s
    s.close()


@pytest.fixture
def crypto(monkeypatch):
    from cryptography.fernet import Fernet
    monkeypatch.setenv("PULSEDESK_ENCRYPTION_KEY", Fernet.generate_key().decode())
    from app.services import crypto_service
    import importlib
    importlib.reload(crypto_service)
    return crypto_service.CryptoService()


@pytest.fixture
def svc(crypto):
    return ProviderConfigService(crypto=crypto)


def test_create_llm_persists_credentials_encrypted(svc, db_session):
    payload = {
        "category": "llm",
        "provider_name": "openai",
        "instance_name": "dev",
        "credentials": {"api_key": "sk-abc-12345"},
        "config": {"model": "gpt-4o"},
    }
    row = svc.upsert(db_session, payload)
    db_session.commit()
    assert row.id is not None
    assert row.credentials_ct != "sk-abc-12345"
    assert "sk-abc" not in (row.credentials_ct or "")
    assert row.credentials_fields == ["api_key"]


def test_view_model_does_not_leak_plaintext(svc, db_session):
    payload = {
        "category": "llm",
        "provider_name": "openai",
        "instance_name": "prod",
        "credentials": {"api_key": "sk-abc-12345"},
    }
    svc.upsert(db_session, payload)
    db_session.commit()
    view = svc.to_view(db_session.query(ProviderConfig).first())
    assert "sk-abc" not in json.dumps(view.model_dump(mode="json"))
    assert view.credential_status == "configured"
    assert view.credential_fields == ["api_key"]


def test_duplicate_llm_instance_raises(svc, db_session):
    payload = {
        "category": "llm",
        "provider_name": "openai",
        "instance_name": "dev",
    }
    svc.upsert(db_session, payload)
    db_session.commit()
    try:
        svc.upsert(db_session, payload)
    except DuplicateProviderError:
        pass
    else:
        raise AssertionError("expected DuplicateProviderError for duplicate LLM instance")


def test_duplicate_single_instance_raises(svc, db_session):
    payload = {
        "category": "cex",
        "provider_name": "binance",
    }
    svc.upsert(db_session, payload)
    db_session.commit()
    try:
        svc.upsert(db_session, payload)
    except DuplicateProviderError:
        pass
    else:
        raise AssertionError("expected DuplicateProviderError for duplicate CEX")


def test_llm_without_instance_name_raises(svc, db_session):
    from pydantic import ValidationError
    try:
        svc.upsert(db_session, {
            "category": "llm",
            "provider_name": "openai",
        })
    except ValidationError:
        pass
    else:
        raise AssertionError("expected ValidationError for LLM without instance_name")


def test_non_llm_with_instance_name_raises(svc, db_session):
    from sqlalchemy.exc import IntegrityError
    payload = {
        "category": "cex",
        "provider_name": "binance",
        "instance_name": "should_not_be_set",
    }
    svc.upsert(db_session, payload)
    try:
        db_session.commit()
    except IntegrityError:
        db_session.rollback()
    else:
        raise AssertionError("expected IntegrityError for non-LLM with instance_name")


def test_enable_disable_toggle(svc, db_session):
    payload = {"category": "cex", "provider_name": "binance"}
    row = svc.upsert(db_session, payload)
    db_session.commit()
    assert row.enabled is True
    svc.set_enabled(db_session, row.id, False)
    db_session.commit()
    assert svc.get(db_session, row.id).enabled is False


def test_get_unknown_returns_none(svc, db_session):
    assert svc.get(db_session, 999) is None
```

- [ ] **Step 2: Run test to confirm it fails**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_config_service.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.providers.config_service'`

- [ ] **Step 3: Implement `config_service.py`**

Write `backend/app/services/providers/config_service.py`:

```python
"""ProviderConfigService — DB CRUD with encryption and uniqueness.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §6.1, §6.2.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.models.provider_config import ProviderConfig
from app.schemas.provider_config import (
    LLMConfig,
    ProviderConfigPayload,
    ProviderConfigView,
)
from app.services.crypto_service import CryptoService
from app.services.providers.base import ProviderCategory
from app.services.providers.crypto import ProviderSecretCodec


class DuplicateProviderError(ValueError):
    """Raised on (category, provider_name, instance_name) uniqueness violation."""


class ProviderConfigService:
    def __init__(self, crypto: CryptoService | None = None) -> None:
        self._crypto = crypto or CryptoService()
        self._codec = ProviderSecretCodec(self._crypto)

    def get(self, db: Session, row_id: int) -> ProviderConfig | None:
        return db.query(ProviderConfig).filter(ProviderConfig.id == row_id).first()

    def get_by_identity(
        self,
        db: Session,
        category: str,
        provider_name: str,
        instance_name: str | None = None,
    ) -> ProviderConfig | None:
        q = db.query(ProviderConfig).filter(
            ProviderConfig.category == category,
            ProviderConfig.provider_name == provider_name,
        )
        if category == ProviderCategory.LLM.value:
            q = q.filter(ProviderConfig.instance_name == instance_name)
        else:
            q = q.filter(ProviderConfig.instance_name.is_(None))
        return q.first()

    def list(
        self,
        db: Session,
        category: str | None = None,
        enabled_only: bool = False,
    ) -> list[ProviderConfig]:
        q = db.query(ProviderConfig)
        if category:
            q = q.filter(ProviderConfig.category == category)
        if enabled_only:
            q = q.filter(ProviderConfig.enabled.is_(True))
        return q.order_by(ProviderConfig.category, ProviderConfig.provider_name).all()

    def upsert(self, db: Session, payload: dict[str, Any]) -> ProviderConfig:
        """Create or update. Pydantic discriminated union validates shape.

        Raises DuplicateProviderError if the (category, provider_name[, instance_name])
        already exists (only for create path; updates on the same row are allowed).
        """
        validated: ProviderConfigPayload = self._validate_payload(payload)

        category = validated.category
        provider_name = validated.provider_name
        instance_name = validated.instance_name
        credentials_dict = validated.credentials

        existing = self.get_by_identity(
            db, category, provider_name, instance_name
        )
        if existing is not None:
            # Update path
            if "config" in payload and payload["config"] is not None:
                existing.config = validated.config
            if "enabled" in payload:
                existing.enabled = validated.enabled
            if "priority" in payload:
                existing.priority = validated.priority
            if credentials_dict is not None:
                existing.credentials_ct = self._codec.encrypt_dict(credentials_dict)
                existing.credentials_fields = self._codec.field_names(credentials_dict)
                existing.credential_status = "configured"
            return existing

        # Create path
        ciphertext = self._codec.encrypt_dict(credentials_dict)
        fields = self._codec.field_names(credentials_dict)
        cred_status = "configured" if credentials_dict else "missing"

        row = ProviderConfig(
            category=category,
            provider_name=provider_name,
            instance_name=instance_name,
            config=validated.config,
            credentials_ct=ciphertext,
            credentials_fields=fields,
            enabled=validated.enabled,
            priority=validated.priority,
            status="unknown",
            credential_status=cred_status,
        )
        # Pre-check duplicate before INSERT (DB check constraint will catch,
        # but we want a clean exception type with code="duplicate").
        if self.get_by_identity(db, category, provider_name, instance_name) is not None:
            raise DuplicateProviderError(
                f"Provider already exists: {category}/{provider_name}"
                + (f"/{instance_name}" if instance_name else "")
            )
        db.add(row)
        db.flush()
        return row

    def delete(self, db: Session, row_id: int) -> bool:
        row = self.get(db, row_id)
        if row is None:
            return False
        db.delete(row)
        db.flush()
        return True

    def set_enabled(self, db: Session, row_id: int, enabled: bool) -> ProviderConfig | None:
        row = self.get(db, row_id)
        if row is None:
            return None
        row.enabled = enabled
        if not enabled:
            row.status = "disabled"
        db.flush()
        return row

    def decrypt_credentials(self, row: ProviderConfig) -> dict | None:
        return self._codec.decrypt_dict(row.credentials_ct)

    def to_view(self, row: ProviderConfig) -> ProviderConfigView:
        return ProviderConfigView(
            id=row.id,
            category=row.category,
            provider_name=row.provider_name,
            instance_name=row.instance_name,
            enabled=row.enabled,
            is_active=row.is_active,
            priority=row.priority,
            status=row.status,
            credential_status=row.credential_status,
            credential_fields=row.credentials_fields or [],
            last_sync_at=row.last_sync_at,
            last_error=row.last_error,
            latency_ms=row.latency_ms,
            rate_limit_remaining=row.rate_limit_remaining,
            rate_limit_reset_at=row.rate_limit_reset_at,
            config=row.config or {},
            updated_at=row.updated_at or datetime.now(timezone.utc),
        )

    @staticmethod
    def _validate_payload(payload: dict[str, Any]) -> Any:
        category = payload.get("category")
        if category == ProviderCategory.LLM.value:
            return LLMConfig.model_validate(payload)
        # Other categories validated by the union at the router; for direct calls
        # we accept the dict as-is (caller is responsible for shape).
        from app.schemas.provider_config import (
            CEXConfig, DeXConfig, NotificationConfig, MarketDataConfig,
            OnchainConfig, SocialConfig, NewsConfig,
        )
        mapping = {
            "cex": CEXConfig, "dex": DeXConfig, "notification": NotificationConfig,
            "market_data": MarketDataConfig, "onchain": OnchainConfig,
            "social": SocialConfig, "news": NewsConfig,
        }
        if category not in mapping:
            raise ValueError(f"Unknown category: {category}")
        return mapping[category].model_validate(payload)
```

- [ ] **Step 4: Run test to confirm it passes**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_config_service.py -v
```

Expected: 8 tests passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/config_service.py backend/tests/providers/test_config_service.py && git commit -m "feat(providers): add ProviderConfigService with encryption and uniqueness"
```

---

### Task 1.9: `health_service.py` — test orchestration

**Files:**
- Create: `backend/app/services/providers/health_service.py`
- Create: `backend/tests/providers/test_health_service.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/test_health_service.py`:

```python
"""Tests for ProviderHealthService — test orchestration and status derivation."""
from __future__ import annotations

from datetime import datetime, timezone

import pytest
from pydantic import BaseModel
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models.provider_config import ProviderConfig
from app.services.providers.base import (
    HealthCheckResult,
    ProviderCategory,
    ProviderStatus,
    ProviderStubBase,
)
from app.services.providers.health_service import ProviderHealthService
from app.services.providers.registry import ProviderRegistry


class _GoodProvider(ProviderStubBase):
    category = ProviderCategory.CEX
    provider_name = "good_cex"
    config_schema = BaseModel

    async def test_connection(self, credentials, config):
        from app.services.providers.base import HealthCheckResult, ProviderStatus
        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=42)


class _AuthFailProvider(ProviderStubBase):
    category = ProviderCategory.CEX
    provider_name = "auth_fail_cex"
    config_schema = BaseModel

    async def test_connection(self, credentials, config):
        from app.services.providers.base import HealthCheckResult, ProviderStatus
        return HealthCheckResult(success=False, status=ProviderStatus.ERROR, error="401 unauthorized")


class _RateLimitedProvider(ProviderStubBase):
    category = ProviderCategory.CEX
    provider_name = "rate_limited_cex"
    config_schema = BaseModel

    async def test_connection(self, credentials, config):
        from app.services.providers.base import HealthCheckResult, ProviderStatus, RateLimitInfo
        return HealthCheckResult(
            success=True,
            status=ProviderStatus.RATE_LIMITED,
            latency_ms=10,
            rate_limit=RateLimitInfo(remaining=0, limit=100, source="header:x-ratelimit-remaining"),
        )


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    s = Session()
    yield s
    s.close()


@pytest.fixture
def registry():
    reg = ProviderRegistry()
    reg.register(_GoodProvider)
    reg.register(_AuthFailProvider)
    reg.register(_RateLimitedProvider)
    return reg


@pytest.fixture
def svc(registry):
    return ProviderHealthService(registry=registry)


@pytest.mark.asyncio
async def test_test_provider_uses_registry(svc, db_session):
    row = ProviderConfig(
        category="cex", provider_name="good_cex", config={},
    )
    db_session.add(row); db_session.commit(); db_session.refresh(row)
    result = await svc.test_from_row(db_session, row)
    assert result.success is True
    assert result.status == "active"
    assert row.is_active is True
    assert row.status == "active"
    assert row.last_sync_at is not None
    assert row.latency_ms == 42


@pytest.mark.asyncio
async def test_auth_failure_records_error(svc, db_session):
    row = ProviderConfig(
        category="cex", provider_name="auth_fail_cex", config={},
    )
    db_session.add(row); db_session.commit(); db_session.refresh(row)
    result = await svc.test_from_row(db_session, row)
    assert result.success is False
    assert row.status == "error"
    assert "401" in row.last_error


@pytest.mark.asyncio
async def test_rate_limited_marks_status(svc, db_session):
    row = ProviderConfig(
        category="cex", provider_name="rate_limited_cex", config={},
    )
    db_session.add(row); db_session.commit(); db_session.refresh(row)
    await svc.test_from_row(db_session, row)
    assert row.status == "rate_limited"
    assert row.rate_limit_remaining == 0


@pytest.mark.asyncio
async def test_disabled_provider_skipped(svc, db_session):
    row = ProviderConfig(
        category="cex", provider_name="good_cex", config={},
        enabled=False,
    )
    db_session.add(row); db_session.commit(); db_session.refresh(row)
    result = await svc.test_from_row(db_session, row)
    assert result.status == ProviderStatus.DISABLED
    assert row.status == "disabled"


def test_status_derivation_table():
    from app.services.providers.health_service import _derive_status
    now = datetime.now(timezone.utc)
    # No rate limit + success
    r = HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=10, error=None, rate_limit=None, checked_at=now)
    assert _derive_status(r, enabled=True, last_sync=now) == "active"
    # Rate limited (remaining=0)
    r = HealthCheckResult(
        success=True, status=ProviderStatus.RATE_LIMITED, latency_ms=10, error=None,
        rate_limit=__import__("app.services.providers.base", fromlist=["RateLimitInfo"]).RateLimitInfo(remaining=0),
        checked_at=now,
    )
    assert _derive_status(r, enabled=True, last_sync=now) == "rate_limited"
    # Disabled
    assert _derive_status(r, enabled=False, last_sync=now) == "disabled"
    # Old sync -> unknown
    old = datetime(2000, 1, 1, tzinfo=timezone.utc)
    assert _derive_status(r, enabled=True, last_sync=old) == "unknown"
```

- [ ] **Step 2: Run test to confirm it fails**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_health_service.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.providers.health_service'`

- [ ] **Step 3: Implement `health_service.py`**

Write `backend/app/services/providers/health_service.py`:

```python
"""ProviderHealthService — orchestrates connection tests and status derivation.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §7.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.provider_config import ProviderConfig
from app.services.providers.base import (
    HealthCheckResult,
    ProviderStatus,
)
from app.services.providers.config_service import ProviderConfigService
from app.services.providers.registry import ProviderRegistry
from app.services.providers.runtime import RateLimitParser

logger = logging.getLogger(__name__)

# 24 hours — providers not tested this long are considered unknown.
UNKNOWN_AFTER_SECONDS = 24 * 3600


def _derive_status(
    result: HealthCheckResult,
    enabled: bool,
    last_sync: datetime | None,
    now: datetime | None = None,
) -> str:
    """Pure function: turn (test result, enabled, last_sync) into a status string."""
    if not enabled:
        return ProviderStatus.DISABLED.value
    if last_sync is None:
        return ProviderStatus.UNKNOWN.value
    now = now or datetime.now(timezone.utc)
    age = (now - last_sync).total_seconds()
    if age > UNKNOWN_AFTER_SECONDS:
        return ProviderStatus.UNKNOWN.value
    if not result.success:
        err = (result.error or "").lower()
        if "401" in err or "403" in err or "expired" in err or "invalid" in err:
            return ProviderStatus.INACTIVE.value
        return ProviderStatus.ERROR.value
    if result.rate_limit and result.rate_limit.remaining == 0:
        return ProviderStatus.RATE_LIMITED.value
    return ProviderStatus.ACTIVE.value


class ProviderHealthService:
    def __init__(
        self,
        registry: ProviderRegistry,
        config_service: ProviderConfigService | None = None,
    ) -> None:
        self._registry = registry
        self._config_service = config_service or ProviderConfigService()

    async def test_from_row(
        self,
        db: Session,
        row: ProviderConfig,
    ) -> HealthCheckResult:
        """Run a connection test using the row's stored config and credentials."""
        from app.services.providers.base import ProviderCategory

        if not row.enabled:
            now = datetime.now(timezone.utc)
            row.status = ProviderStatus.DISABLED.value
            row.last_sync_at = now
            return HealthCheckResult(
                success=False, status=ProviderStatus.DISABLED,
                latency_ms=None, error="disabled", rate_limit=None, checked_at=now,
            )

        try:
            category = ProviderCategory(row.category)
        except ValueError:
            return self._record_error(row, f"unknown category: {row.category}")

        if not self._registry.has(category, row.provider_name):
            return self._record_error(row, f"unknown provider: {row.provider_name}")

        try:
            adapter = self._registry.get(category, row.provider_name)
        except KeyError as e:
            return self._record_error(row, str(e))

        creds = self._config_service.decrypt_credentials(row) or {}
        config = row.config or {}

        try:
            result: HealthCheckResult = await adapter.test_connection(creds, config)
        except Exception as exc:
            return self._record_error(row, f"adapter exception: {str(exc)[:200]}")

        now = datetime.now(timezone.utc)
        # Try to refresh rate limit from headers if the adapter exposes one
        # (the result already contains it; nothing else to do here).

        status = _derive_status(result, enabled=row.enabled, last_sync=now)
        row.status = status
        row.is_active = (status == ProviderStatus.ACTIVE.value)
        row.last_sync_at = now
        row.latency_ms = result.latency_ms
        row.last_error = (result.error or "")[:200] if not result.success else None
        if result.rate_limit:
            row.rate_limit_remaining = result.rate_limit.remaining
            row.rate_limit_reset_at = result.rate_limit.reset_at
        else:
            # Do not overwrite a previously-observed rate limit if this call didn't return one
            pass
        db.flush()
        return result

    async def test_ephemeral(
        self,
        category: str,
        provider_name: str,
        credentials: dict,
        config: dict,
    ) -> HealthCheckResult:
        """Run a connection test without touching the DB. For paste-then-test UX."""
        from app.services.providers.base import ProviderCategory

        try:
            cat = ProviderCategory(category)
        except ValueError as e:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error=f"unknown category: {category}", latency_ms=None, rate_limit=None,
                checked_at=datetime.now(timezone.utc),
            )
        if not self._registry.has(cat, provider_name):
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error=f"unknown provider: {provider_name}", latency_ms=None, rate_limit=None,
                checked_at=datetime.now(timezone.utc),
            )
        adapter = self._registry.get(cat, provider_name)
        try:
            return await adapter.test_connection(credentials, config)
        except Exception as exc:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error=str(exc)[:200], latency_ms=None, rate_limit=None,
                checked_at=datetime.now(timezone.utc),
            )

    def _record_error(self, row: ProviderConfig, message: str) -> HealthCheckResult:
        now = datetime.now(timezone.utc)
        row.last_error = message[:200]
        row.last_sync_at = now
        row.status = ProviderStatus.ERROR.value
        row.is_active = False
        return HealthCheckResult(
            success=False, status=ProviderStatus.ERROR,
            latency_ms=None, error=message, rate_limit=None, checked_at=now,
        )
```

- [ ] **Step 4: Run test to confirm it passes**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_health_service.py -v
```

Expected: 5 tests passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/health_service.py backend/tests/providers/test_health_service.py && git commit -m "feat(providers): add ProviderHealthService with status derivation"
```

---

### Task 1.10: `scheduler.py` — native asyncio tick

**Files:**
- Create: `backend/app/services/providers/scheduler.py`
- Create: `backend/tests/providers/test_scheduler.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/test_scheduler.py`:

```python
"""Tests for ProviderHealthScheduler and ProviderHealthTickPolicy."""
from __future__ import annotations

from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models.provider_config import ProviderConfig
from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.scheduler import ProviderHealthTickPolicy


def _row(category, provider_name, enabled=True, last_sync_at=None, instance_name=None):
    return ProviderConfig(
        category=category, provider_name=provider_name,
        instance_name=instance_name, config={}, enabled=enabled,
        last_sync_at=last_sync_at, status="unknown",
    )


def test_tick_policy_selects_enabled_only():
    rows = [
        _row("cex", "binance", enabled=True),
        _row("cex", "bybit", enabled=False),
        _row("cex", "okx", enabled=True),
    ]
    policy = ProviderHealthTickPolicy(batch_size=10)
    selected = policy.select(rows, now=datetime.now(timezone.utc))
    names = [r.provider_name for r in selected]
    assert "binance" in names
    assert "okx" in names
    assert "bybit" not in names


def test_tick_policy_orders_oldest_first():
    now = datetime.now(timezone.utc)
    old = now.replace(year=2020)
    rows = [
        _row("cex", "fresh", last_sync_at=now),
        _row("cex", "old", last_sync_at=old),
        _row("cex", "never", last_sync_at=None),
    ]
    policy = ProviderHealthTickPolicy(batch_size=10)
    selected = policy.select(rows, now=now)
    names = [r.provider_name for r in selected]
    # NULLS FIRST means 'never' comes first
    assert names[0] == "never"
    assert names[1] == "old"
    assert names[2] == "fresh"


def test_tick_policy_respects_batch_size():
    rows = [_row("cex", f"p{i}") for i in range(20)]
    policy = ProviderHealthTickPolicy(batch_size=5)
    selected = policy.select(rows, now=datetime.now(timezone.utc))
    assert len(selected) == 5


def test_scheduler_interval_zero_disables_loop():
    from app.services.providers.scheduler import ProviderHealthScheduler
    sched = ProviderHealthScheduler(interval_s=0)
    assert sched.enabled is False


- [ ] **Step 2: Run test to confirm it fails**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_scheduler.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.providers.scheduler'`

- [ ] **Step 3: Implement `scheduler.py`**

Write `backend/app/services/providers/scheduler.py`:

```python
"""Provider health scheduler — native asyncio, zero new dependencies.

Sub-project 1 of the Provider Adapter Foundation.
See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §7.5.
"""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.database import SessionLocal
from app.models.provider_config import ProviderConfig
from app.services.providers.health_service import ProviderHealthService

logger = logging.getLogger(__name__)


class ProviderHealthTickPolicy:
    """Pure / unit-testable: pick which providers to test in a tick."""

    def __init__(self, batch_size: int = 10) -> None:
        self.batch_size = batch_size

    def select(
        self, rows: list[ProviderConfig], now: datetime | None = None
    ) -> list[ProviderConfig]:
        now = now or datetime.now(timezone.utc)
        eligible = [r for r in rows if r.enabled]
        # Sort: NULLS FIRST, then by last_sync_at ASC.
        eligible.sort(
            key=lambda r: (r.last_sync_at is not None, r.last_sync_at or now)
        )
        return eligible[: self.batch_size]


class ProviderHealthScheduler:
    """Periodically tests enabled providers using ProviderHealthService."""

    def __init__(
        self,
        interval_s: int | None = None,
        batch_size: int | None = None,
        session_factory: sessionmaker | None = None,
        health_service: ProviderHealthService | None = None,
    ) -> None:
        self.interval_s = interval_s if interval_s is not None else settings.provider_health_interval_s
        self.batch_size = batch_size if batch_size is not None else settings.provider_health_batch_size
        self.enabled = self.interval_s > 0
        self._session_factory = session_factory or SessionLocal
        self._health = health_service or ProviderHealthService(
            registry=self._build_registry()
        )
        self._task: asyncio.Task | None = None
        self._stop = asyncio.Event()

    @staticmethod
    def _build_registry():
        from app.services.providers.registry import registry
        return registry

    async def start(self) -> None:
        if not self.enabled:
            logger.info("Provider health scheduler disabled (interval_s=0)")
            return
        if self._task is not None:
            return
        from app.services.providers.categories import register_all  # noqa: F401
        self._task = asyncio.create_task(self._loop(), name="provider-health-scheduler")
        logger.info(
            "Provider health scheduler started (interval_s=%s, batch_size=%s)",
            self.interval_s, self.batch_size,
        )

    async def stop(self) -> None:
        if self._task is None:
            return
        self._stop.set()
        try:
            await asyncio.wait_for(self._task, timeout=5.0)
        except asyncio.TimeoutError:
            self._task.cancel()
        self._task = None
        logger.info("Provider health scheduler stopped")

    async def tick_once(self, db: Session | None = None) -> int:
        from app.services.providers.registry import registry

        if db is None:
            db = self._session_factory()
        try:
            rows = db.execute(
                select(ProviderConfig).order_by(
                    ProviderConfig.last_sync_at.asc().nulls_first()
                )
            ).scalars().all()
            policy = ProviderHealthTickPolicy(batch_size=self.batch_size)
            selected = policy.select(rows)
            if not selected:
                return 0
            tested = 0
            async with asyncio.TaskGroup() as tg:
                for row in selected:
                    tg.create_task(self._safe_test(db, row))
                    tested += 1
            db.commit()
            return tested
        finally:
            try:
                db.close()
            except Exception:
                pass

    async def _safe_test(self, db: Session, row: ProviderConfig) -> None:
        try:
            await self._health.test_from_row(db, row)
        except Exception:
            logger.exception("Provider test failed for id=%s", row.id)

    async def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                await asyncio.wait_for(self._stop.wait(), timeout=self.interval_s)
                return
            except asyncio.TimeoutError:
                pass
            try:
                await self.tick_once()
            except Exception:
                logger.exception("Provider health tick failed")
```

- [ ] **Step 4: Run test to confirm it passes**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/test_scheduler.py -v
```

Expected: 4 tests passed.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/providers/scheduler.py backend/tests/providers/test_scheduler.py && git commit -m "feat(providers): add native asyncio health scheduler with tick policy"
```

---

### Task 1.11: Alembic migration — drop + create

**Files:**
- Create: `backend/alembic/versions/2026_06_16_xxxx_provider_foundation.py`

- [ ] **Step 1: Generate the migration skeleton**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m alembic revision -m "provider foundation: drop ai_provider_configs, create provider_configs + provider_audit_logs, add AIUsageLog.provider_config_id"
```

Note the generated filename and substitute it in the next step.

- [ ] **Step 2: Replace the generated file with the explicit upgrade/downgrade**

Open the generated file and replace its `upgrade()` and `downgrade()` bodies with:

```python
"""provider foundation: drop ai_provider_configs, create provider_configs + provider_audit_logs, add AIUsageLog.provider_config_id

Revision ID: <auto>
Revises: <auto>
Create Date: 2026-06-16
"""
from alembic import op
import sqlalchemy as sa


revision = "<auto>"
down_revision = "<auto>"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "ai_usage_logs",
        sa.Column("provider_config_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_ai_usage_logs_provider_config",
        "ai_usage_logs", "provider_configs",
        ["provider_config_id"], ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "provider_configs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("category", sa.String(), nullable=False),
        sa.Column("provider_name", sa.String(), nullable=False),
        sa.Column("instance_name", sa.String(), nullable=True),
        sa.Column("config", sa.JSON(), nullable=False),
        sa.Column("credentials_ct", sa.Text(), nullable=True),
        sa.Column("credentials_fields", sa.JSON(), nullable=True),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("priority", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("status", sa.String(), nullable=False, server_default=sa.text("'unknown'")),
        sa.Column("credential_status", sa.String(), nullable=False, server_default=sa.text("'missing'")),
        sa.Column("last_sync_at", sa.DateTime(), nullable=True),
        sa.Column("last_error", sa.String(), nullable=True),
        sa.Column("latency_ms", sa.Integer(), nullable=True),
        sa.Column("rate_limit_remaining", sa.Integer(), nullable=True),
        sa.Column("rate_limit_reset_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "(category = 'llm' AND instance_name IS NOT NULL) OR "
            "(category != 'llm' AND instance_name IS NULL)",
            name="ck_instance_name_by_category",
        ),
    )
    op.create_index("ix_provider_config_category", "provider_configs", ["category"])
    op.create_index("ix_provider_config_provider_name", "provider_configs", ["provider_name"])
    op.create_index("ix_provider_config_cat_name", "provider_configs", ["category", "provider_name"])
    op.create_index("ix_provider_config_enabled", "provider_configs", ["enabled"])

    op.create_table(
        "provider_audit_logs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("provider_id", sa.Integer(), nullable=False),
        sa.Column("action", sa.String(), nullable=False),
        sa.Column("actor", sa.String(), nullable=True),
        sa.Column("before_hash", sa.String(), nullable=True),
        sa.Column("after_hash", sa.String(), nullable=True),
        sa.Column("ip", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["provider_id"], ["provider_configs.id"],
            ondelete="CASCADE",
        ),
    )
    op.create_index("ix_provider_audit_logs_provider_id", "provider_audit_logs", ["provider_id"])
    op.create_index("ix_provider_audit_logs_created_at", "provider_audit_logs", ["created_at"])

    op.drop_table("ai_provider_configs")


def downgrade() -> None:
    op.create_table(
        "ai_provider_configs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("provider", sa.String(), nullable=False),
        sa.Column("api_key_encrypted", sa.String(), nullable=True),
        sa.Column("base_url", sa.String(), nullable=True),
        sa.Column("model", sa.String(), nullable=False),
        sa.Column("is_active", sa.Boolean()),
        sa.Column("priority", sa.Integer()),
        sa.Column("created_at", sa.DateTime()),
        sa.Column("updated_at", sa.DateTime()),
    )
    op.drop_index("ix_provider_audit_logs_created_at", table_name="provider_audit_logs")
    op.drop_index("ix_provider_audit_logs_provider_id", table_name="provider_audit_logs")
    op.drop_table("provider_audit_logs")
    op.drop_index("ix_provider_config_enabled", table_name="provider_configs")
    op.drop_index("ix_provider_config_cat_name", table_name="provider_configs")
    op.drop_index("ix_provider_config_provider_name", table_name="provider_configs")
    op.drop_index("ix_provider_config_category", table_name="provider_configs")
    op.drop_table("provider_configs")
    op.drop_constraint("fk_ai_usage_logs_provider_config", "ai_usage_logs", type_="foreignkey")
    op.drop_column("ai_usage_logs", "provider_config_id")
```

- [ ] **Step 3: Apply the migration**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m alembic upgrade head
```

Expected: `Running upgrade  -> <rev>, provider foundation: ...`

- [ ] **Step 4: Verify the schema**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -c "
from app.database import engine
from sqlalchemy import inspect
insp = inspect(engine)
print('tables:', [t for t in insp.get_table_names() if 'provider' in t or 'usage' in t])
print('provider_configs cols:', [c['name'] for c in insp.get_columns('provider_configs')])
print('check constraints:', [c['name'] for c in insp.get_check_constraints('provider_configs')])
"
```

Expected: `['ai_usage_logs', 'provider_audit_logs', 'provider_configs']`; check constraint `ck_instance_name_by_category` present.

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/alembic/versions/ && git commit -m "feat(providers): alembic migration for provider foundation"
```

---

### Task 1.12: Wire up `database.py` and `main.py`

**Files:**
- Modify: `backend/app/database.py` (or `app/models/__init__.py` if models are re-exported there)
- Modify: `backend/app/main.py`

- [ ] **Step 1: Find where existing models are imported**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal && grep -rn "from app.models" backend/app/main.py backend/app/database.py backend/app/models/__init__.py 2>/dev/null
```

If a single `app/models/__init__.py` re-exports models, edit that file instead. The goal is to make `app.models.provider_config.ProviderConfig` importable at app startup.

- [ ] **Step 2: Add the new models to the import block**

Add:
```python
from app.models.provider_config import ProviderAuditLog, ProviderConfig  # noqa: F401
```

- [ ] **Step 3: Find the FastAPI lifespan block in `main.py`**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal && grep -n "lifespan\|asynccontextmanager\|app\.include_router" backend/app/main.py
```

- [ ] **Step 4: Register the admin/providers router in `main.py`**

Add to the `app.include_router(...)` calls:
```python
from app.routers.admin.providers import router as admin_providers_router
# ...
app.include_router(admin_providers_router)
```

(If main.py has no lifespan yet, add one — see Task 3.7 for the full pattern.)

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/main.py backend/app/database.py && git commit -m "feat(providers): register provider models and admin router"
```

---

## PR 2: Adapters (6 real + 12 stub)

### Task 2.1: Categories package + LLM openai (real)

**Files:**
- Create: `backend/app/services/providers/categories/__init__.py`
- Create: `backend/app/services/providers/categories/llm/__init__.py`
- Create: `backend/app/services/providers/categories/llm/openai.py`
- Create: `backend/tests/providers/categories/__init__.py`
- Create: `backend/tests/providers/categories/test_llm_openai.py`

- [ ] **Step 1: Write the failing test**

Write `backend/tests/providers/categories/test_llm_openai.py`:

```python
"""Tests for the OpenAI LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.openai import OpenAIProvider


@pytest.mark.asyncio
async def test_happy_path_returns_active():
    adapter = OpenAIProvider()
    with patch("app.services.providers.categories.llm.openai.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.json = AsyncMock(return_value={"data": [{"id": "gpt-4o"}]})
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        result = await adapter.test_connection(
            {"api_key": "sk-test"},
            {"base_url": "https://api.openai.com/v1", "model": "gpt-4o"},
        )
    assert result.success is True
    assert result.status == ProviderStatus.ACTIVE
    assert result.latency_ms is not None


@pytest.mark.asyncio
async def test_401_returns_error():
    adapter = OpenAIProvider()
    with patch("app.services.providers.categories.llm.openai.aiohttp.ClientSession") as M:
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
        result = await adapter.test_connection(
            {"api_key": "bad"},
            {"base_url": "https://api.openai.com/v1", "model": "gpt-4o"},
        )
    assert result.success is False
    assert "401" in (result.error or "")


@pytest.mark.asyncio
async def test_missing_api_key_returns_error():
    adapter = OpenAIProvider()
    result = await adapter.test_connection(
        {}, {"base_url": "https://api.openai.com/v1", "model": "gpt-4o"},
    )
    assert result.success is False
    assert "api_key" in (result.error or "").lower()


def test_meta_attributes():
    a = OpenAIProvider()
    assert a.category == ProviderCategory.LLM
    assert a.provider_name == "openai"
    assert a.is_multi_instance is True
```

- [ ] **Step 2: Run test to confirm it fails**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/categories/test_llm_openai.py -v
```

Expected: FAIL with `ModuleNotFoundError`

- [ ] **Step 3: Implement `openai.py`**

Write `backend/app/services/providers/categories/llm/openai.py`:

```python
"""OpenAI LLM provider adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class OpenAIConfig(BaseModel):
    base_url: str = Field(default="https://api.openai.com/v1")
    model: str = Field(default="gpt-4o")
    timeout_s: float = Field(default=10.0)


class OpenAIProvider:
    category = ProviderCategory.LLM
    provider_name = "openai"
    is_multi_instance = True
    config_schema = OpenAIConfig

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

- [ ] **Step 4: Create categories package init files**

Write `backend/app/services/providers/categories/__init__.py`:

```python
"""Auto-registers all category sub-packages on import."""


def register_all() -> None:
    from app.services.providers.categories import llm  # noqa: F401
    from app.services.providers.categories import cex  # noqa: F401
    from app.services.providers.categories import dex  # noqa: F401
    from app.services.providers.categories import notification  # noqa: F401
    from app.services.providers.categories import market_data  # noqa: F401
    from app.services.providers.categories import onchain  # noqa: F401
    from app.services.providers.categories import social  # noqa: F401
    from app.services.providers.categories import news  # noqa: F401
```

Write `backend/app/services/providers/categories/llm/__init__.py`:

```python
"""LLM provider registrations."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

from app.services.providers.categories.llm.openai import OpenAIProvider
from app.services.providers.categories.llm.anthropic import AnthropicProvider
from app.services.providers.categories.llm.ollama import OllamaProvider


def _make_stub(provider_name: str):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.LLM
        provider_name = provider_name
        is_multi_instance = True
    _Stub.__name__ = f"{provider_name.title()}Provider"
    return _Stub


for _name in ("deepseek", "qwen", "zhipu", "moonshot", "gemini", "groq", "azure_openai"):
    registry.register(_make_stub(_name))

for _cls in (OpenAIProvider, AnthropicProvider, OllamaProvider):
    registry.register(_cls)
```

- [ ] **Step 5: Create anthropic.py and ollama.py (real) plus the 7 stub files**

`backend/app/services/providers/categories/llm/anthropic.py`:
```python
"""Anthropic LLM provider adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class AnthropicConfig(BaseModel):
    model: str = Field(default="claude-sonnet-4-20250514")
    timeout_s: float = Field(default=10.0)


class AnthropicProvider:
    category = ProviderCategory.LLM
    provider_name = "anthropic"
    is_multi_instance = True
    config_schema = AnthropicConfig

    async def test_connection(self, credentials, config):
        api_key = credentials.get("api_key", "")
        if not api_key:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, error="api_key required", latency_ms=None, rate_limit=None)
        cfg = self.config_schema.model_validate(config)
        url = "https://api.anthropic.com/v1/messages"
        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
        body = {"model": cfg.model, "max_tokens": 1, "messages": [{"role": "user", "content": "ping"}]}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(url, headers=headers, json=body) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status in (200, 400):
                        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=latency, rate_limit=None)
                    text = await resp.text()
                    status = ProviderStatus.INACTIVE if resp.status in (401, 403) else ProviderStatus.ERROR
                    return HealthCheckResult(success=False, status=status, latency_ms=latency, error=f"HTTP {resp.status}: {text[:120]}")
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
```

`backend/app/services/providers/categories/llm/ollama.py`:
```python
"""Ollama local LLM provider adapter. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class OllamaConfig(BaseModel):
    base_url: str = Field(default="http://localhost:11434")
    model: str = Field(default="qwen2.5:7b")
    timeout_s: float = Field(default=5.0)


class OllamaProvider:
    category = ProviderCategory.LLM
    provider_name = "ollama"
    is_multi_instance = True
    config_schema = OllamaConfig

    async def test_connection(self, credentials, config):
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/tags"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
                        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=latency, rate_limit=None)
                    text = await resp.text()
                    return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=latency, error=f"HTTP {resp.status}: {text[:120]}")
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
```

For each of the 7 stub files (`deepseek.py`, `qwen.py`, `zhipu.py`, `moonshot.py`, `gemini.py`, `groq.py`, `azure_openai.py`), write the same one-liner pattern (the actual stub is registered in `__init__.py`; the file exists for clarity):

`backend/app/services/providers/categories/llm/deepseek.py`:
```python
"""DeepSeek LLM provider stub. Real impl deferred to sub-project 2."""
# The DeepSeekProvider is registered in app.services.providers.categories.llm
# via the _make_stub helper. This file exists for clarity and future expansion.
```

(Same for the other 6.)

- [ ] **Step 6: Run the openai test, confirm it passes**

Run:
```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/categories/test_llm_openai.py -v
```

Expected: 4 tests passed.

- [ ] **Step 7: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/ backend/tests/providers/categories/ && git commit -m "feat(providers): add LLM adapters (openai/anthropic/ollama real, 7 stubs)"
```

---

### Task 2.2: LLM anthropic and ollama real tests

**Files:**
- Create: `backend/tests/providers/categories/test_llm_anthropic.py`
- Create: `backend/tests/providers/categories/test_llm_ollama.py`

- [ ] **Step 1: Write `test_llm_anthropic.py`**

```python
"""Tests for the Anthropic LLM provider adapter."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderStatus
from app.services.providers.categories.llm.anthropic import AnthropicProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = AnthropicProvider()
    with patch("app.services.providers.categories.llm.anthropic.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.post = MagicMock(return_value=resp)
        r = await a.test_connection({"api_key": "sk-ant"}, {"model": "claude-sonnet-4-20250514"})
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = AnthropicProvider()
    with patch("app.services.providers.categories.llm.anthropic.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 401
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="invalid x-api-key")
        session.post = MagicMock(return_value=resp)
        r = await a.test_connection({"api_key": "bad"}, {"model": "claude-sonnet-4-20250514"})
    assert r.status == ProviderStatus.INACTIVE


def test_meta():
    a = AnthropicProvider()
    assert a.provider_name == "anthropic"
    assert a.is_multi_instance is True
```

- [ ] **Step 2: Write `test_llm_ollama.py`**

```python
"""Tests for the Ollama LLM provider adapter."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderStatus
from app.services.providers.categories.llm.ollama import OllamaProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = OllamaProvider()
    with patch("app.services.providers.categories.llm.ollama.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection({}, {"base_url": "http://localhost:11434", "model": "qwen2.5:7b"})
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_unreachable_returns_error():
    a = OllamaProvider()
    with patch("app.services.providers.categories.llm.ollama.aiohttp.ClientSession") as M:
        M.return_value.__aenter__ = AsyncMock(side_effect=Exception("connection refused"))
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        r = await a.test_connection({}, {"base_url": "http://nope:11434", "model": "qwen2.5:7b"})
    assert r.success is False
    assert r.status == ProviderStatus.ERROR
```

- [ ] **Step 3: Run, expect pass**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/categories/test_llm_anthropic.py tests/providers/categories/test_llm_ollama.py -v
```

Expected: 5 tests passed.

- [ ] **Step 4: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/tests/providers/categories/ && git commit -m "test(providers): add anthropic and ollama tests"
```

---

### Task 2.3: CEX binance (real), freqtrade (real), and 3 stubs

**Files:**
- Create: `backend/app/services/providers/categories/cex/__init__.py`
- Create: `backend/app/services/providers/categories/cex/binance.py`
- Create: `backend/app/services/providers/categories/cex/freqtrade.py`
- Create stub files: `backend/app/services/providers/categories/cex/{okx,bybit,bitget}.py`
- Create: `backend/tests/providers/categories/test_cex_binance.py`
- Create: `backend/tests/providers/categories/test_cex_freqtrade.py`

- [ ] **Step 1: Write `binance.py`**

```python
"""Binance CEX adapter. Real implementation using CCXT public API."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser


class BinanceConfig(BaseModel):
    base_url: str = Field(default="https://api.binance.com")
    timeout_s: float = Field(default=10.0)


class BinanceProvider:
    category = ProviderCategory.CEX
    provider_name = "binance"
    is_multi_instance = False
    config_schema = BinanceConfig

    async def test_connection(self, credentials, config):
        cfg = self.config_schema.model_validate(config)
        url = f"{cfg.base_url.rstrip('/')}/api/v3/ping"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=latency, rate_limit=rl)
                    text = await resp.text()
                    return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=latency, error=f"HTTP {resp.status}: {text[:120]}", rate_limit=rl)
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
```

- [ ] **Step 2: Write `freqtrade.py`**

```python
"""Freqtrade CEX adapter. Pings the running Freqtrade instance."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class FreqtradeConfig(BaseModel):
    url: str = Field(default="http://localhost:8080")
    username: str = Field(default="freqtrade")
    password: str = Field(default="freqtrade")
    timeout_s: float = Field(default=5.0)


class FreqtradeProvider:
    category = ProviderCategory.CEX
    provider_name = "freqtrade"
    is_multi_instance = False
    config_schema = FreqtradeConfig

    def __init__(self, client_factory=None) -> None:
        """client_factory is injectable for tests; defaults to FreqtradeClient."""
        self._client_factory = client_factory

    async def test_connection(self, credentials, config):
        cfg = self.config_schema.model_validate(config)
        try:
            if self._client_factory is not None:
                client = self._client_factory(
                    base_url=cfg.url, username=cfg.username, password=cfg.password,
                )
            else:
                from app.services.freqtrade_client import FreqtradeClient
                client = FreqtradeClient(
                    base_url=cfg.url, username=cfg.username, password=cfg.password,
                )
            ok = await client.ping()
            if ok:
                return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=None, rate_limit=None)
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error="ping returned False")
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
```

- [ ] **Step 3: Write `cex/__init__.py`**

```python
"""CEX provider registrations."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

from app.services.providers.categories.cex.binance import BinanceProvider
from app.services.providers.categories.cex.freqtrade import FreqtradeProvider


for _name in ("okx", "bybit", "bitget"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.CEX
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title()}Provider"
    registry.register(_Stub)

for _cls in (BinanceProvider, FreqtradeProvider):
    registry.register(_cls)
```

- [ ] **Step 4: Write the 3 stub files (one-liners)**

`backend/app/services/providers/categories/cex/okx.py`:
```python
"""OKX CEX stub. Real impl deferred to sub-project 3."""
```

(Same for `bybit.py` and `bitget.py`.)

- [ ] **Step 5: Write `test_cex_binance.py`**

```python
"""Tests for the Binance CEX adapter."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderStatus
from app.services.providers.categories.cex.binance import BinanceProvider


@pytest.mark.asyncio
async def test_200_returns_active_with_rate_limit():
    a = BinanceProvider()
    with patch("app.services.providers.categories.cex.binance.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.headers = {"X-MBX-USED-WEIGHT-1M": "100"}
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection({}, {"base_url": "https://api.binance.com"})
    assert r.success is True
    assert r.rate_limit is not None
    assert r.rate_limit.remaining == 6000 - 100


def test_meta():
    a = BinanceProvider()
    assert a.provider_name == "binance"
    assert a.is_multi_instance is False
```

- [ ] **Step 6: Write `test_cex_freqtrade.py`**

```python
"""Tests for the Freqtrade CEX adapter."""
import pytest

from app.services.providers.base import ProviderStatus
from app.services.providers.categories.cex.freqtrade import FreqtradeProvider


class _FakeClient:
    def __init__(self, *, ping_result):
        self._ping_result = ping_result

    async def ping(self):
        return self._ping_result


@pytest.mark.asyncio
async def test_ping_ok_returns_active():
    a = FreqtradeProvider(client_factory=lambda **kw: _FakeClient(ping_result=True))
    r = await a.test_connection({}, {"url": "http://x", "username": "u", "password": "p"})
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_ping_false_returns_error():
    a = FreqtradeProvider(client_factory=lambda **kw: _FakeClient(ping_result=False))
    r = await a.test_connection({}, {"url": "http://x", "username": "u", "password": "p"})
    assert r.success is False
    assert r.status == ProviderStatus.ERROR
```

- [ ] **Step 7: Run, expect pass**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/categories/test_cex_binance.py tests/providers/categories/test_cex_freqtrade.py -v
```

Expected: 4 tests passed.

- [ ] **Step 8: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/cex/ backend/tests/providers/categories/test_cex_binance.py backend/tests/providers/categories/test_cex_freqtrade.py && git commit -m "feat(providers): add CEX adapters (binance/freqtrade real, okx/bybit/bitget stubs)"
```

---

### Task 2.4: DeX stubs

**Files:**
- Create: `backend/app/services/providers/categories/dex/__init__.py`
- Create stub files: `backend/app/services/providers/categories/dex/{gmx,hyperliquid,dydx}.py`

- [ ] **Step 1: Write `dex/__init__.py`**

```python
"""DeX provider registrations. All stubs (sub-project 5+)."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

for _name in ("gmx", "hyperliquid", "dydx"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.DEX
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title()}Provider"
    registry.register(_Stub)
```

- [ ] **Step 2: Write the 3 stub files (one-liners)**

`backend/app/services/providers/categories/dex/gmx.py`:
```python
"""GMX DeX stub. Real impl deferred to sub-project 5+."""
```

(Same for `hyperliquid.py` and `dydx.py`.)

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/dex/ && git commit -m "feat(providers): add DeX stubs (gmx, hyperliquid, dydx)"
```

---

### Task 2.5: Notification telegram (real) and 3 stubs

**Files:**
- Create: `backend/app/services/providers/categories/notification/__init__.py`
- Create: `backend/app/services/providers/categories/notification/telegram.py`
- Create stub files: `backend/app/services/providers/categories/notification/{discord,email,webhook}.py`
- Create: `backend/tests/providers/categories/test_notification_telegram.py`

- [ ] **Step 1: Write `telegram.py`**

```python
"""Telegram notification provider. Real implementation."""
from __future__ import annotations

import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)


class TelegramConfig(BaseModel):
    dry_run: bool = Field(default=True)
    timeout_s: float = Field(default=10.0)


class TelegramProvider:
    category = ProviderCategory.NOTIFICATION
    provider_name = "telegram"
    is_multi_instance = False
    config_schema = TelegramConfig

    async def test_connection(self, credentials, config):
        bot_token = credentials.get("bot_token", "")
        chat_id = credentials.get("chat_id", "")
        if not bot_token or not chat_id:
            return HealthCheckResult(
                success=False, status=ProviderStatus.ERROR,
                error="bot_token and chat_id required",
                latency_ms=None, rate_limit=None,
            )
        cfg = self.config_schema.model_validate(config)
        if cfg.dry_run:
            return HealthCheckResult(
                success=True, status=ProviderStatus.ACTIVE,
                latency_ms=None, rate_limit=None,
            )
        url = f"https://api.telegram.org/bot{bot_token}/getMe"
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    if resp.status == 200:
                        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=latency, rate_limit=None)
                    text = await resp.text()
                    status = ProviderStatus.INACTIVE if resp.status in (401, 403) else ProviderStatus.ERROR
                    return HealthCheckResult(success=False, status=status, latency_ms=latency, error=f"HTTP {resp.status}: {text[:120]}")
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
```

- [ ] **Step 2: Write `notification/__init__.py`**

```python
"""Notification provider registrations."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

from app.services.providers.categories.notification.telegram import TelegramProvider

for _name in ("discord", "email", "webhook"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.NOTIFICATION
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title()}Provider"
    registry.register(_Stub)

registry.register(TelegramProvider)
```

- [ ] **Step 3: Write the 3 stub files (one-liners)**

`backend/app/services/providers/categories/notification/discord.py`:
```python
"""Discord notification stub. Real impl deferred to sub-project 6."""
```

(Same for `email.py` and `webhook.py`.)

- [ ] **Step 4: Write `test_notification_telegram.py`**

```python
"""Tests for the Telegram notification adapter."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderStatus
from app.services.providers.categories.notification.telegram import TelegramProvider


@pytest.mark.asyncio
async def test_missing_creds_returns_error():
    a = TelegramProvider()
    r = await a.test_connection({}, {"dry_run": True})
    assert r.status == ProviderStatus.ERROR
    assert "bot_token" in r.error


@pytest.mark.asyncio
async def test_dry_run_succeeds():
    a = TelegramProvider()
    r = await a.test_connection(
        {"bot_token": "x", "chat_id": "1"}, {"dry_run": True},
    )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_live_200_returns_active():
    a = TelegramProvider()
    with patch("app.services.providers.categories.notification.telegram.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"bot_token": "x", "chat_id": "1"}, {"dry_run": False},
        )
    assert r.success is True
```

- [ ] **Step 5: Run, expect pass**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/providers/categories/test_notification_telegram.py -v
```

Expected: 3 tests passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/notification/ backend/tests/providers/categories/test_notification_telegram.py && git commit -m "feat(providers): add notification adapters (telegram real, 3 stubs)"
```

---

### Task 2.6: Market data, onchain, social, news stubs (11 stubs total)

**Files:**
- Create: `backend/app/services/providers/categories/market_data/__init__.py` + 4 stub files
- Create: `backend/app/services/providers/categories/onchain/__init__.py` + 3 stub files
- Create: `backend/app/services/providers/categories/social/__init__.py` + 2 stub files
- Create: `backend/app/services/providers/categories/news/__init__.py` + 2 stub files

- [ ] **Step 1: Write each sub-package `__init__.py`**

`backend/app/services/providers/categories/market_data/__init__.py`:
```python
"""Market data provider registrations. All stubs (sub-project 4)."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

for _name in ("kline", "orderbook", "funding", "oi"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.MARKET_DATA
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title()}Provider"
    registry.register(_Stub)
```

`backend/app/services/providers/categories/onchain/__init__.py`:
```python
"""On-chain provider registrations. All stubs (sub-project 5)."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

for _name in ("glassnode", "cryptoquant", "whale_alert"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.ONCHAIN
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title().replace('_', '')}Provider"
    registry.register(_Stub)
```

`backend/app/services/providers/categories/social/__init__.py`:
```python
"""Social provider registrations. All stubs (sub-project 5)."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

for _name in ("cryptocompare_social", "lunarcrush"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.SOCIAL
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title().replace('_', '')}Provider"
    registry.register(_Stub)
```

`backend/app/services/providers/categories/news/__init__.py`:
```python
"""News provider registrations. All stubs (sub-project 5)."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

for _name in ("cryptocompare_news", "cryptopanic"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.NEWS
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title().replace('_', '')}Provider"
    registry.register(_Stub)
```

- [ ] **Step 2: Write 11 one-liner stub files**

For each provider file (`kline.py`, `orderbook.py`, `funding.py`, `oi.py`, `glassnode.py`, `cryptoquant.py`, `whale_alert.py`, `cryptocompare_social.py`, `lunarcrush.py`, `cryptocompare_news.py`, `cryptopanic.py`), write:

`backend/app/services/providers/categories/market_data/kline.py`:
```python
"""Kline market data stub. Real impl deferred to sub-project 4."""
```

(Each file gets the matching one-liner. 11 files total.)

- [ ] **Step 3: Smoke-test that all stubs register without error**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -c "
from app.services.providers.categories import register_all
register_all()
from app.services.providers.registry import registry
for cat in ['llm', 'cex', 'dex', 'notification', 'market_data', 'onchain', 'social', 'news']:
    print(cat, registry.list_providers(cat))
"
```

Expected output: each category lists its providers.

- [ ] **Step 4: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/providers/categories/ && git commit -m "feat(providers): add market_data/onchain/social/news stubs (11 providers)"
```

---

## PR 3: Router & Migration

### Task 3.1: Slim down `ai_providers.py`

**Files:**
- Modify: `backend/app/routers/ai_providers.py`

- [ ] **Step 1: Read the current file end-to-end**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && wc -l app/routers/ai_providers.py
```

- [ ] **Step 2: Remove the LLM provider sections**

Delete the LLM list / config / test endpoint blocks and their request/response models. Keep:
- `routing-rules` GET/PUT
- `privacy-rules` GET/PUT
- `models_status` / `models_runtime` / `models_preload` (paths under `/api/ai/models/*`)

The module-level `_llm_service` singleton can also be removed.

- [ ] **Step 3: Verify the file still parses**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -c "from app.routers.ai_providers import router; print([r.path for r in router.routes])"
```

Expected: only `/routing-rules`, `/privacy-rules`, `/models/*`, `/usage` remain.

- [ ] **Step 4: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/routers/ai_providers.py && git commit -m "refactor(providers): drop LLM CRUD/test endpoints from ai_providers router"
```

---

### Task 3.2: Drop `data_source_manager.py` and `data_source_bff.py`

**Files:**
- Delete: `backend/app/services/data_source_manager.py`
- Delete: `backend/app/routers/data_source_bff.py`
- Remove the include_router call in `main.py` for the data_source_bff router

- [ ] **Step 1: Find all importers**

```bash
cd /Users/novspace/workspace/phosphor-terminal && grep -rln "data_source_manager\|data_source_bff" backend/ 2>/dev/null
```

- [ ] **Step 2: Delete the files and remove the include_router call**

```bash
cd /Users/novspace/workspace/phosphor-terminal && rm backend/app/services/data_source_manager.py backend/app/routers/data_source_bff.py
```

Edit `backend/app/main.py` — remove any `app.include_router(..._data_source_bff_router)` line.

- [ ] **Step 3: Run pytest to catch broken imports**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/ -q 2>&1 | tail -20
```

Expected: no `ImportError`.

- [ ] **Step 4: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add -A backend/ && git commit -m "refactor(providers): drop legacy DataSourceManager and data_source_bff"
```

---

### Task 3.3: Rewrite `llm_service.py` as a registry-based priority selector

**Files:**
- Modify: `backend/app/services/llm_service.py`

- [ ] **Step 1: Find all callers**

```bash
cd /Users/novspace/workspace/phosphor-terminal && grep -rln "from app.services.llm_service\|import llm_service" backend/ 2>/dev/null
```

- [ ] **Step 2: Replace the file**

```python
"""LLMService — thin facade that selects a provider via ProviderRegistry."""
from __future__ import annotations

import logging
from typing import Any

from app.models.provider_config import ProviderConfig
from app.services.providers.base import ProviderCategory
from app.services.providers.config_service import ProviderConfigService
from app.services.providers.registry import registry

logger = logging.getLogger(__name__)


class LLMService:
    def __init__(self, config_service: ProviderConfigService | None = None) -> None:
        self._config_service = config_service or ProviderConfigService()

    async def list_available(self) -> list[dict[str, Any]]:
        from app.database import SessionLocal
        with SessionLocal() as db:
            rows = self._config_service.list(db, category=ProviderCategory.LLM.value)
        return [
            {
                "provider": r.provider_name,
                "instance": r.instance_name,
                "active": r.is_active,
                "priority": r.priority,
                "status": r.status,
                "model": (r.config or {}).get("model", ""),
            }
            for r in rows
        ]

    def get_usage_stats(self) -> dict[str, Any]:
        return {"calls": 0, "tokens": 0, "providers": {}}

    def select_provider(self, db, instance_name: str | None = None) -> ProviderConfig | None:
        rows = self._config_service.list(db, category=ProviderCategory.LLM.value, enabled_only=True)
        candidates = [r for r in rows if r.is_active and r.credential_status == "configured"]
        if instance_name:
            candidates = [r for r in candidates if r.instance_name == instance_name]
        if not candidates:
            return None
        candidates.sort(key=lambda r: r.priority)
        return candidates[0]

    def providers(self) -> list[Any]:
        return [
            registry.get(ProviderCategory.LLM, name)
            for name in registry.list_providers(ProviderCategory.LLM)
        ]


def create_llm_service_from_env() -> LLMService:
    return LLMService()
```

- [ ] **Step 3: Run pytest, fix any callers that broke**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/ -q 2>&1 | tail -30
```

- [ ] **Step 4: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/llm_service.py && git commit -m "refactor(providers): rewrite LLMService as registry-based priority selector"
```

---

### Task 3.4: Rewrite `telegram_notifier.py` as a thin wrapper

**Files:**
- Modify: `backend/app/services/telegram_notifier.py`

- [ ] **Step 1: Replace the file**

```python
"""telegram_notifier — thin wrapper that pulls creds from provider_configs."""
from __future__ import annotations

import logging
from typing import Any, Optional

import aiohttp

from app.services.providers.base import ProviderCategory
from app.services.providers.config_service import ProviderConfigService

logger = logging.getLogger(__name__)


def build_risk_message(event: dict[str, Any]) -> str:
    severity = str(event.get("severity", "info")).upper()
    event_type = event.get("event_type", "risk_event")
    description = event.get("description") or "Risk event generated."
    action = event.get("action_taken") or "review_required"
    return f"[PulseDesk][{severity}] {event_type}: {description} Action: {action}"


async def send_telegram_notification(
    event: dict[str, Any],
    *,
    dry_run: bool = True,
    bot_token: Optional[str] = None,
    chat_id: Optional[str] = None,
) -> dict[str, Any]:
    from app.database import SessionLocal

    message = build_risk_message(event)

    if not bot_token or not chat_id:
        svc = ProviderConfigService()
        with SessionLocal() as db:
            row = svc.get_by_identity(
                db, category=ProviderCategory.NOTIFICATION.value,
                provider_name="telegram",
            )
        if row and row.enabled and row.credentials_ct:
            creds = svc.decrypt_credentials(row) or {}
            bot_token = bot_token or creds.get("bot_token")
            chat_id = chat_id or creds.get("chat_id")
            cfg = row.config or {}
            if cfg.get("dry_run"):
                dry_run = True

    if dry_run or not bot_token or not chat_id:
        return {
            "status": "dry_run",
            "message": message,
            "destination": chat_id or "not_configured",
        }

    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    try:
        timeout = aiohttp.ClientTimeout(total=10)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(url, json={"chat_id": chat_id, "text": message}) as resp:
                if resp.status == 200:
                    return {
                        "status": "sent",
                        "message": message,
                        "destination": chat_id,
                        "telegram_response": await resp.json(),
                    }
                return {
                    "status": "error",
                    "message": message,
                    "destination": chat_id,
                    "detail": f"HTTP {resp.status}: {await resp.text()}",
                }
    except Exception as exc:
        logger.exception("Telegram send failed")
        return {
            "status": "error",
            "message": message,
            "destination": chat_id,
            "detail": str(exc),
        }
```

- [ ] **Step 2: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/telegram_notifier.py && git commit -m "refactor(providers): rewrite telegram_notifier to read creds from provider_configs"
```

---

### Task 3.5: Rewrite `dependency_checker.py` to read provider_configs

**Files:**
- Modify: `backend/app/services/dependency_checker.py`

- [ ] **Step 1: Add a DB-first lookup function**

Append to the file (or replace the LLM env-var block):

```python
def _llm_provider_db_status(provider_name: str, instance_name: str = "default") -> dict:
    from app.services.providers.config_service import ProviderConfigService
    from app.services.providers.base import ProviderCategory
    from app.database import SessionLocal
    svc = ProviderConfigService()
    with SessionLocal() as db:
        row = svc.get_by_identity(
            db, category=ProviderCategory.LLM.value,
            provider_name=provider_name, instance_name=instance_name,
        )
    if row and row.enabled and row.credential_status == "configured":
        return {"status": "configured", "source": "db", "is_active": row.is_active}
    if row:
        return {"status": "configured", "source": "db", "missing_credentials": True}
    return {"status": "not_configured", "source": "db"}
```

- [ ] **Step 2: Replace the LLM entries in `check_all_dependencies`**

In `check_all_dependencies`, replace the LLM section of `external_services` with:
```python
external_services["openai"] = _llm_provider_db_status("openai")
external_services["anthropic"] = _llm_provider_db_status("anthropic")
external_services["deepseek"] = _llm_provider_db_status("deepseek")
external_services["qwen"] = _llm_provider_db_status("qwen")
external_services["zhipu"] = _llm_provider_db_status("zhipu")
external_services["moonshot"] = _llm_provider_db_status("moonshot")
external_services["mimo"] = _llm_provider_db_status("mimo")
external_services["gemini"] = _llm_provider_db_status("gemini")
external_services["groq"] = _llm_provider_db_status("groq")
external_services["azure_openai"] = _llm_provider_db_status("azure_openai")
```

(Keep the freqtrade, ollama, telegram checks as they are.)

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/services/dependency_checker.py && git commit -m "refactor(providers): dependency_checker reads LLM status from provider_configs"
```

---

### Task 3.6: Build `routers/admin/providers.py`

**Files:**
- Create: `backend/app/routers/admin/__init__.py`
- Create: `backend/app/routers/admin/providers.py`

- [ ] **Step 1: Create the package init**

`backend/app/routers/admin/__init__.py`:
```python
"""Admin API package."""
```

- [ ] **Step 2: Write the admin/providers router**

`backend/app/routers/admin/providers.py`:
```python
"""Admin API for provider configuration: CRUD, test, enable/disable, audit."""
from __future__ import annotations

import hashlib
import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.provider_config import ProviderAuditLog, ProviderConfig
from app.schemas.provider_config import (
    HealthCheckResultSchema, ProviderConfigPayload, ProviderConfigView,
    ProviderSummaryView, ProviderTestRequest,
)
from app.services.providers.base import ProviderCategory
from app.services.providers.config_service import (
    DuplicateProviderError, ProviderConfigService,
)
from app.services.providers.health_service import ProviderHealthService
from app.services.providers.registry import registry
from app.services.providers.scheduler import ProviderHealthScheduler

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/providers", tags=["admin-providers"])


def _get_client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _record_audit(db, provider_id, action, actor="api", before_hash=None, after_hash=None, ip=None):
    db.add(ProviderAuditLog(
        provider_id=provider_id, action=action, actor=actor,
        before_hash=before_hash, after_hash=after_hash, ip=ip,
    ))


def _hash_creds(credentials_ct):
    if not credentials_ct:
        return None
    return hashlib.sha256(credentials_ct.encode()).hexdigest()[:8]


@router.get("/categories")
def list_categories() -> dict:
    out = {}
    for cat in ProviderCategory:
        providers = []
        for name in registry.list_providers(cat):
            adapter = registry.get(cat, name)
            providers.append({"name": name, "is_multi_instance": adapter.is_multi_instance})
        out[cat.value] = providers
    return {"categories": out}


@router.get("", response_model=list[ProviderConfigView])
def list_providers(category: str | None = Query(default=None), db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    rows = svc.list(db, category=category)
    return [svc.to_view(r) for r in rows]


@router.get("/{provider_id}", response_model=ProviderConfigView)
def get_provider(provider_id: int, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.get(db, provider_id)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    return svc.to_view(row)


@router.post("", response_model=ProviderConfigView, status_code=201)
def create_provider(payload: ProviderConfigPayload, request: Request, db: Session = Depends(get_db)):
    try:
        category = ProviderCategory(payload.category)
    except ValueError:
        raise HTTPException(status_code=400, detail={"code": "invalid_payload"})
    if not registry.has(category, payload.provider_name):
        raise HTTPException(status_code=400, detail={"code": "unknown_provider"})

    svc = ProviderConfigService()
    try:
        row = svc.upsert(db, payload.model_dump())
        db.commit()
        db.refresh(row)
    except DuplicateProviderError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail={"code": "duplicate", "message": str(e)})

    _record_audit(db, row.id, "create", after_hash=_hash_creds(row.credentials_ct), ip=_get_client_ip(request))
    db.commit()
    return svc.to_view(row)


@router.put("/{provider_id}", response_model=ProviderConfigView)
def update_provider(provider_id: int, payload: dict, request: Request, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.get(db, provider_id)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    from app.schemas.provider_config import (
        LLMConfig, CEXConfig, DeXConfig, NotificationConfig,
        MarketDataConfig, OnchainConfig, SocialConfig, NewsConfig,
    )
    schema_map = {
        "llm": LLMConfig, "cex": CEXConfig, "dex": DeXConfig,
        "notification": NotificationConfig, "market_data": MarketDataConfig,
        "onchain": OnchainConfig, "social": SocialConfig, "news": NewsConfig,
    }
    Schema = schema_map[row.category]
    payload_with_id = {**payload, "category": row.category, "provider_name": row.provider_name}
    if row.category != "llm":
        payload_with_id["instance_name"] = None
    else:
        payload_with_id["instance_name"] = row.instance_name
    validated = Schema.model_validate(payload_with_id)
    before_hash = _hash_creds(row.credentials_ct)
    try:
        svc.upsert(db, validated.model_dump())
        db.commit()
    except DuplicateProviderError:
        db.rollback()
        raise HTTPException(status_code=409, detail={"code": "duplicate"})
    db.refresh(row)
    after_hash = _hash_creds(row.credentials_ct)
    _record_audit(db, row.id, "update", before_hash=before_hash, after_hash=after_hash, ip=_get_client_ip(request))
    db.commit()
    return svc.to_view(row)


@router.delete("/{provider_id}", status_code=204)
def delete_provider(provider_id: int, request: Request, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    if not svc.delete(db, provider_id):
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    _record_audit(db, provider_id, "delete", ip=_get_client_ip(request))
    db.commit()


@router.post("/{provider_id}/test", response_model=HealthCheckResultSchema)
async def test_provider(provider_id: int, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.get(db, provider_id)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    health = ProviderHealthService(registry=registry)
    result = await health.test_from_row(db, row)
    db.commit()
    return HealthCheckResultSchema(
        success=result.success, status=result.status.value,
        latency_ms=result.latency_ms, error=result.error,
        rate_limit=result.rate_limit.model_dump() if result.rate_limit else None,
        checked_at=result.checked_at,
    )


@router.post("/test", response_model=HealthCheckResultSchema)
async def test_ephemeral(body: ProviderTestRequest):
    health = ProviderHealthService(registry=registry)
    result = await health.test_ephemeral(
        category=body.category, provider_name=body.provider_name,
        credentials=body.credentials or {}, config=body.config,
    )
    return HealthCheckResultSchema(
        success=result.success, status=result.status.value,
        latency_ms=result.latency_ms, error=result.error,
        rate_limit=result.rate_limit.model_dump() if result.rate_limit else None,
        checked_at=result.checked_at,
    )


@router.post("/{provider_id}/enable", response_model=ProviderConfigView)
def enable_provider(provider_id: int, request: Request, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.set_enabled(db, provider_id, True)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    db.commit()
    _record_audit(db, row.id, "enable", ip=_get_client_ip(request))
    db.commit()
    return svc.to_view(row)


@router.post("/{provider_id}/disable", response_model=ProviderConfigView)
def disable_provider(provider_id: int, request: Request, db: Session = Depends(get_db)):
    svc = ProviderConfigService()
    row = svc.set_enabled(db, provider_id, False)
    if row is None:
        raise HTTPException(status_code=404, detail={"code": "not_found"})
    db.commit()
    _record_audit(db, row.id, "disable", ip=_get_client_ip(request))
    db.commit()
    return svc.to_view(row)


@router.post("/{provider_id}/rotate-credentials", status_code=501)
def rotate_credentials(provider_id: int):
    raise HTTPException(status_code=501, detail={"code": "not_implemented"})


@router.get("/{provider_id}/audit-log")
def get_audit_log(provider_id: int, limit: int = Query(default=50, ge=1, le=500), db: Session = Depends(get_db)):
    rows = db.query(ProviderAuditLog).filter(
        ProviderAuditLog.provider_id == provider_id
    ).order_by(ProviderAuditLog.created_at.desc()).limit(limit).all()
    return [{
        "id": r.id, "action": r.action, "actor": r.actor,
        "before_hash": r.before_hash, "after_hash": r.after_hash,
        "ip": r.ip, "created_at": r.created_at.isoformat() if r.created_at else None,
    } for r in rows]


@router.get("/health-summary", response_model=ProviderSummaryView)
def health_summary(db: Session = Depends(get_db)):
    rows = db.query(ProviderConfig).all()
    by_category = {}
    total_active = total_error = total_disabled = total_configured = 0
    for r in rows:
        by_category[r.category] = by_category.get(r.category, 0) + 1
        if r.status == "active": total_active += 1
        if r.status == "error": total_error += 1
        if not r.enabled: total_disabled += 1
        if r.credential_status == "configured": total_configured += 1
    return ProviderSummaryView(
        by_category=by_category, total_active=total_active, total_error=total_error,
        total_disabled=total_disabled, total_configured=total_configured,
        total=len(rows), checked_at=datetime.now(timezone.utc),
    )


@router.post("/health-tick")
async def health_tick():
    sched = ProviderHealthScheduler()
    tested = await sched.tick_once()
    return {"tested": tested}
```

- [ ] **Step 3: Smoke-import**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -c "from app.routers.admin.providers import router; print([r.path for r in router.routes])"
```

Expected: list of paths under `/api/admin/providers`.

- [ ] **Step 4: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/routers/admin/ && git commit -m "feat(providers): add /api/admin/providers/* router with 14 endpoints"
```

---

### Task 3.7: Wire admin router + scheduler into main.py

**Files:**
- Modify: `backend/app/main.py`

- [ ] **Step 1: Add imports**

```python
from app.routers.admin.providers import router as admin_providers_router
from app.services.providers.scheduler import ProviderHealthScheduler
```

- [ ] **Step 2: Add or extend the lifespan**

If `main.py` has no `lifespan`, add this:

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    from app.services.providers.categories import register_all
    register_all()
    sched = ProviderHealthScheduler()
    await sched.start()
    try:
        yield
    finally:
        await sched.stop()
```

Pass `lifespan=lifespan` to `FastAPI(...)`.

- [ ] **Step 3: Register the router**

```python
app.include_router(admin_providers_router)
```

- [ ] **Step 4: Smoke-start the app**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && timeout 5 python3 run.py 2>&1 | head -20
```

Expected: "Provider health scheduler started" log; no traceback.

- [ ] **Step 5: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/app/main.py && git commit -m "feat(providers): wire admin router and start health scheduler in lifespan"
```

---

### Task 3.8: Integration tests for the admin API

**Files:**
- Create: `backend/tests/integration/test_admin_providers_api.py`

- [ ] **Step 1: Write the test**

```python
"""End-to-end tests for /api/admin/providers/* using FastAPI TestClient."""
from __future__ import annotations

import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app.main import app


@pytest.fixture(autouse=True)
def fernet_key(monkeypatch):
    key = Fernet.generate_key().decode()
    monkeypatch.setenv("PULSEDESK_ENCRYPTION_KEY", key)
    import importlib
    from app.services import crypto_service
    importlib.reload(crypto_service)
    yield key


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    s = Session()
    yield s
    s.close()


@pytest.fixture
def client(db_session, monkeypatch):
    def _override():
        try:
            yield db_session
        finally:
            pass
    app.dependency_overrides[get_db] = _override
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def test_categories_endpoint_lists_registered(client):
    r = client.get("/api/admin/providers/categories")
    assert r.status_code == 200
    cats = r.json()["categories"]
    assert "llm" in cats
    assert "cex" in cats
    assert "openai" in [p["name"] for p in cats["llm"]]
    assert "binance" in [p["name"] for p in cats["cex"]]


def test_create_persists_credentials_encrypted(client, db_session):
    r = client.post("/api/admin/providers", json={
        "category": "llm", "provider_name": "openai", "instance_name": "test",
        "credentials": {"api_key": "sk-plaintext-12345"},
        "config": {"model": "gpt-4o"},
    })
    assert r.status_code == 201, r.text
    body = r.json()
    assert "sk-plaintext" not in str(body)
    assert body["credential_fields"] == ["api_key"]
    assert body["credential_status"] == "configured"

    # Verify the row in DB has ciphertext, not plaintext
    from app.models.provider_config import ProviderConfig
    row = db_session.query(ProviderConfig).first()
    assert "sk-plaintext" not in (row.credentials_ct or "")


def test_get_does_not_leak_plaintext(client):
    client.post("/api/admin/providers", json={
        "category": "llm", "provider_name": "openai", "instance_name": "x",
        "credentials": {"api_key": "sk-secret-9999"},
    })
    r = client.get("/api/admin/providers")
    assert r.status_code == 200
    assert "sk-secret" not in str(r.json())


def test_duplicate_single_instance_returns_409(client):
    p = {"category": "cex", "provider_name": "binance"}
    r1 = client.post("/api/admin/providers", json=p)
    assert r1.status_code == 201
    r2 = client.post("/api/admin/providers", json=p)
    assert r2.status_code == 409
    assert r2.json()["detail"]["code"] == "duplicate"


def test_duplicate_llm_instance_returns_409(client):
    p = {"category": "llm", "provider_name": "openai", "instance_name": "x"}
    assert client.post("/api/admin/providers", json=p).status_code == 201
    assert client.post("/api/admin/providers", json=p).status_code == 409


def test_unknown_provider_returns_400(client):
    r = client.post("/api/admin/providers", json={"category": "cex", "provider_name": "nope"})
    assert r.status_code == 400
    assert r.json()["detail"]["code"] == "unknown_provider"


def test_enable_disable_toggle(client):
    r = client.post("/api/admin/providers", json={"category": "cex", "provider_name": "binance"})
    pid = r.json()["id"]
    r2 = client.post(f"/api/admin/providers/{pid}/disable")
    assert r2.status_code == 200
    assert r2.json()["enabled"] is False
    r3 = client.post(f"/api/admin/providers/{pid}/enable")
    assert r3.json()["enabled"] is True


def test_audit_log_records_actions(client):
    r = client.post("/api/admin/providers", json={"category": "cex", "provider_name": "binance"})
    pid = r.json()["id"]
    client.post(f"/api/admin/providers/{pid}/disable")
    client.post(f"/api/admin/providers/{pid}/enable")
    audit = client.get(f"/api/admin/providers/{pid}/audit-log").json()
    actions = [a["action"] for a in audit]
    assert "create" in actions
    assert "disable" in actions
    assert "enable" in actions


def test_rotate_returns_501(client):
    r = client.post("/api/admin/providers", json={"category": "cex", "provider_name": "binance"})
    pid = r.json()["id"]
    r2 = client.post(f"/api/admin/providers/{pid}/rotate-credentials")
    assert r2.status_code == 501
```

- [ ] **Step 2: Run, expect pass**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/integration/test_admin_providers_api.py -v
```

Expected: 8 tests passed.

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/tests/integration/test_admin_providers_api.py && git commit -m "test(providers): add admin API integration tests"
```

---

### Task 3.9: iOS plumbing — `APIAIProviders.swift`

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APIAIProviders.swift`

- [ ] **Step 1: Read the existing file**

```bash
cd /Users/novspace/workspace/phosphor-terminal && wc -l macos-app/AlphaLoop/Services/APIAIProviders.swift
```

- [ ] **Step 2: Rewrite to point at `/api/admin/providers`**

Replace method bodies to call the new endpoints. The pattern:

```swift
// listProviders() → calls /api/admin/providers?category=llm
func listProviders() async throws -> [ProviderConfigView] {
    return try await client.get("/api/admin/providers?category=llm")
}

// updateConfig → POST /api/admin/providers with discriminated-union body
func updateConfig(body: ProviderUpsertBody) async throws -> ProviderConfigView {
    return try await client.post("/api/admin/providers", body: body)
}

// testConnection → POST /api/admin/providers/test (ephemeral)
func testConnection(body: ProviderTestBody) async throws -> HealthCheckResult {
    return try await client.post("/api/admin/providers/test", body: body)
}
```

Update Codable structs to match `ProviderConfigView` (snake_case via `CodingKeys`).

- [ ] **Step 3: Confirm swift build**

```bash
cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -20
```

- [ ] **Step 4: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add macos-app/AlphaLoop/Services/APIAIProviders.swift && git commit -m "refactor(ios): point APIAIProviders at /api/admin/providers"
```

---

### Task 3.10: iOS plumbing — `APIDataSources.swift`

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APIDataSources.swift`

- [ ] **Step 1: Rewrite to consume the flat `[ProviderConfigView]` shape**

```swift
// list() → /api/admin/providers (no filter)
func list() async throws -> [ProviderConfigView] {
    return try await client.get("/api/admin/providers")
}

// testConnection(id:) → /api/admin/providers/{id}/test
func testConnection(providerId: Int) async throws -> HealthCheckResult {
    return try await client.post("/api/admin/providers/\(providerId)/test")
}

// enable / disable → /api/admin/providers/{id}/enable and /disable
func enable(providerId: Int) async throws -> ProviderConfigView { ... }
func disable(providerId: Int) async throws -> ProviderConfigView { ... }
```

Update Codable to match `ProviderConfigView`.

- [ ] **Step 2: Confirm swift build**

```bash
cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -20
```

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add macos-app/AlphaLoop/Services/APIDataSources.swift && git commit -m "refactor(ios): point APIDataSources at /api/admin/providers"
```

---

### Task 3.11: iOS plumbing — `APINotifications.swift`

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APINotifications.swift`

- [ ] **Step 1: Replace the telegram dry-run call**

```swift
func telegramDryRun(botToken: String, chatId: String, dryRun: Bool) async throws -> HealthCheckResult {
    return try await client.post("/api/admin/providers/test", body: [
        "category": "notification",
        "provider_name": "telegram",
        "credentials": ["bot_token": botToken, "chat_id": chatId],
        "config": ["dry_run": dryRun],
    ])
}
```

- [ ] **Step 2: Confirm swift build**

```bash
cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -20
```

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add macos-app/AlphaLoop/Services/APINotifications.swift && git commit -m "refactor(ios): telegram test uses /api/admin/providers/test"
```

---

## PR 4: Documentation (4 files)

### Task 4.1: `docs/integrations/api-audit.md`

**Files:**
- Create: `docs/integrations/api-audit.md`

- [ ] **Step 1: Write the file**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/integrations/api-audit.md && git commit -m "docs: integrations/api-audit (LLM/Notification/Exchange real; rest stubbed)"
```

---

### Task 4.2: `docs/settings/configuration-model.md`

**Files:**
- Create: `docs/settings/configuration-model.md`

- [ ] **Step 1: Write the file**

```markdown
# Configuration Model — Provider Adapter Foundation

The provider configuration system uses a single `provider_configs` table
backed by a Pydantic discriminated union. This document describes the
schema, the validation flow, the encryption boundary, and the audit
trail.

## Tables

### `provider_configs`

Single table for all 8 categories. Column-by-column:

| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | autoincrement |
| `category` | String | one of `llm/cex/dex/notification/market_data/onchain/social/news` |
| `provider_name` | String | the registered provider name (e.g. `binance`) |
| `instance_name` | String? | required for LLM; NULL for all other categories |
| `config` | JSON | non-sensitive configuration (Pydantic-validated) |
| `credentials_ct` | Text? | Fernet-encrypted JSON of the credentials dict |
| `credentials_fields` | JSON? | list of credential field names (e.g. `["api_key"]`) |
| `enabled` | Boolean | admin on/off (default true) |
| `is_active` | Boolean | derived: `True iff status='active'` |
| `priority` | Integer | LLM routing priority; 0 for other categories |
| `status` | String | derived enum: `unknown/active/inactive/error/rate_limited/disabled` |
| `credential_status` | String | `missing/configured/expired/invalid` |
| `last_sync_at` | DateTime? | last test_connection time |
| `last_error` | String? | truncated to 200 chars |
| `latency_ms` | Integer? | last test latency |
| `rate_limit_remaining` | Integer? | from response header |
| `rate_limit_reset_at` | DateTime? | from response header |
| `created_at` | DateTime | server-side |
| `updated_at` | DateTime | on update |

### Constraints

- `ck_instance_name_by_category`: LLM must have `instance_name`; others must NOT.
- Uniqueness is enforced at the service layer:
  - LLM: `(category, provider_name, instance_name)` must be unique
  - Other: `(category, provider_name, instance_name IS NULL)` must be unique
- Indices: `ix_provider_config_category`, `ix_provider_config_provider_name`, `ix_provider_config_cat_name` (composite), `ix_provider_config_enabled`.

### `provider_audit_logs`

Records every config-changing action:

| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | |
| `provider_id` | Integer FK | CASCADE on delete |
| `action` | String | `create/update/enable/disable/test/rotate/delete` |
| `actor` | String? | who triggered (e.g. `api`) |
| `before_hash` | String? | SHA-256-8 of pre-state `credentials_ct` (never plaintext) |
| `after_hash` | String? | SHA-256-8 of post-state `credentials_ct` |
| `ip` | String? | client IP from request |
| `created_at` | DateTime | server-side |

### `ai_usage_logs` (existing; soft FK added)

A nullable `provider_config_id` FK links each usage record back to the
config that produced it. The FK uses `ON DELETE SET NULL` so deleting a
config does not lose historical usage data.

## Pydantic Discrimriminated Union

`app.schemas.provider_config.ProviderConfigPayload` is the canonical
input type for create/update endpoints. It is built as:

```python
ProviderConfigPayload = Annotated[
    LLMConfig | CEXConfig | DeXConfig | NotificationConfig
    | MarketDataConfig | OnchainConfig | SocialConfig | NewsConfig,
    Field(discriminator="category"),
]
```

Each subclass of `ProviderConfigBase` overrides the `category` field
with a `Literal[...]` so Pydantic picks the right validator.

### `LLMConfig`

- `instance_name: str` (required)
- `config: dict` (e.g. `{"model": "gpt-4o"}`)
- `credentials: dict | None` (e.g. `{"api_key": "sk-..."}`)

### `CEXConfig`

- `config: dict` (e.g. `{"base_url": "https://api.binance.com"}`)
- `credentials: dict | None` (e.g. `{"api_key", "api_secret", "passphrase"}`)

(Other categories follow the same pattern; see
`app/schemas/provider_config.py` for the full list.)

## View Model

`ProviderConfigView` is what every read endpoint returns. **It never
contains plaintext credentials.** Field-by-field:

| Field | Source | Notes |
|---|---|---|
| `id` | `provider_configs.id` | |
| `category` | same | |
| `provider_name` | same | |
| `instance_name` | same | NULL for non-LLM |
| `enabled` | same | |
| `is_active` | same | derived |
| `priority` | same | |
| `status` | same | derived |
| `credential_status` | same | |
| `credential_fields` | `credentials_fields` JSON | e.g. `["api_key"]` |
| `last_sync_at` | same | |
| `last_error` | same | truncated to 200 chars |
| `latency_ms` | same | |
| `rate_limit_remaining` | same | from response header |
| `rate_limit_reset_at` | same | from response header |
| `config` | `config` JSON | masked via `adapter.mask_config()` |
| `updated_at` | same | |

## Encryption

`app/services/crypto_service.py:CryptoService` (existing) is the single
encryption boundary.

**Write path** (in `ProviderConfigService.upsert`):
1. Receive plaintext `credentials` in payload.
2. `json.dumps(creds, sort_keys=True, ensure_ascii=False)`.
3. `CryptoService.encrypt(payload)` → `credentials_ct`.
4. `sorted(creds.keys())` → `credentials_fields`.
5. Set `credential_status="configured"`.

**Read path** (in `ProviderConfigService.decrypt_credentials`):
1. `CryptoService.decrypt(credentials_ct)` → JSON string.
2. `json.loads(...)` → dict.
3. **Never** returned to the iOS client; only used inside
   `ProviderHealthService.test_from_row` to call the adapter.

**Read-side fallback** (dev mode without `PULSEDESK_ENCRYPTION_KEY`):
`CryptoService` runs in passthrough mode. This is acceptable for dev but
**must not** be used in production.

**Tampered ciphertext**: `CryptoService.decrypt` returns the input
unchanged on failure (with a debug log). `ProviderConfigService` returns
`None` on JSON decode failure, and the row's `credential_status` is set
to `invalid` by `ProviderHealthService`.

## Status Derivation

`health_service._derive_status` is a pure function:

| Input | Output |
|---|---|
| `enabled=False` | `disabled` |
| `last_sync` is None | `unknown` |
| `last_sync` > 24h ago | `unknown` |
| `success=False` and error contains `401/403/expired/invalid` | `inactive` |
| `success=False` (other) | `error` |
| `success=True` and `rate_limit.remaining == 0` | `rate_limited` |
| `success=True` (other) | `active` |

## Multi-Instance Rule

Only LLM supports multiple instances. For LLM, the tuple
`(category, provider_name, instance_name)` is unique. For all other
categories, the tuple `(category, provider_name)` is unique (and
`instance_name` is enforced NULL by the `ck_instance_name_by_category`
check constraint).

The registry (`ProviderRegistry`) validates at registration time that
`is_multi_instance` matches the category rule (LLM=True, all others=False).

## Migration (one-time)

The Alembic migration `2026_06_16_xxxx_provider_foundation.py`:
1. Adds nullable `provider_config_id` FK to `ai_usage_logs`.
2. Creates `provider_configs` and `provider_audit_logs`.
3. Drops `ai_provider_configs` (no production data to preserve).

The migration is **not reversible in production** without restoring a
backup of `ai_provider_configs`. In dev, `alembic downgrade -1` brings
the schema back, but no rows.

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` §6
- API contracts: `docs/backend/api-contracts.md`
- Database notes: `docs/database/schema-notes.md`
```

- [ ] **Step 2: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/settings/configuration-model.md && git commit -m "docs: settings/configuration-model (ProviderConfig table + Pydantic union)"
```

---

### Task 4.3: `docs/backend/api-contracts.md`

**Files:**
- Create: `docs/backend/api-contracts.md`

- [ ] **Step 1: Write the file**

```markdown
# API Contracts — Provider Admin API

The Provider Admin API is served under `/api/admin/providers/*`. It
exposes CRUD + test + enable/disable + audit operations on the
`provider_configs` table.

This document specifies every endpoint, the request/response schema,
the error codes, and the load-bearing invariants.

## Conventions

- All endpoints return JSON.
- All errors use FastAPI's `HTTPException` with `{"detail": {"code": "...", "message": "..."}, "status_code": N}`.
- All `provider_id` path parameters are integers referring to `provider_configs.id`.
- `instance_name` is required for `llm` and **must be NULL** for all other categories (enforced at the DB level).

## Critical Invariants

These rules apply to **every** endpoint in this surface:

1. **No GET response** includes `credentials_ct` (decrypted or raw), plaintext `credentials`, or any field absent from `ProviderConfigView`.
2. **POST /test** (ephemeral) accepts plaintext credentials but does **not** persist.
3. **POST /providers** encrypts credentials on the way in; sets `credential_status="configured"`; records `credentials_fields`.
4. **PUT /{id}** replacing credentials overwrites the prior ciphertext; audit log stores `before_hash`/`after_hash` (SHA-256 first 8 hex) — never plaintext.
5. **enable/disable** writes audit with no credential change.
6. **Unique-constraint violations** surface as HTTP 409 with `code="duplicate"`.
7. **Unknown provider_name** (not in registry) → HTTP 400 with `code="unknown_provider"`.
8. **Rate-limit parser** errors are silent (return `None`); they never raise into the request path.

## Endpoints

### `GET /api/admin/providers/categories`

Returns all 8 categories with their registered provider names.

**Response (200):**
```json
{
  "categories": {
    "llm": [{"name": "openai", "is_multi_instance": true}, ...],
    "cex": [{"name": "binance", "is_multi_instance": false}, ...],
    ...
  }
}
```

### `GET /api/admin/providers?category={category}`

Lists all configs (or filtered by category). Returns `[ProviderConfigView]`.

**Response (200):** list of `ProviderConfigView` objects (see
`docs/settings/configuration-model.md`).

### `GET /api/admin/providers/{id}`

Single config.

**Response (200):** `ProviderConfigView`.
**Errors:** 404 `not_found`.

### `POST /api/admin/providers`

Create a new config. Body is `ProviderConfigPayload` (Pydantic
discriminated union by `category`).

**Response (201):** `ProviderConfigView`.
**Errors:**
- 400 `invalid_payload` (Pydantic validation failed)
- 400 `unknown_provider` (provider_name not in registry for category)
- 409 `duplicate` (unique constraint violated)

### `PUT /api/admin/providers/{id}`

Update an existing config. Body is a partial dict (any subset of
`config`, `credentials`, `enabled`, `priority`). `category` and
`provider_name` are taken from the row, not the body.

**Response (200):** updated `ProviderConfigView`.
**Errors:**
- 400 `invalid_payload`
- 404 `not_found`
- 409 `duplicate` (only if a different row would now collide; the row's own update never collides)

### `DELETE /api/admin/providers/{id}`

Hard delete. Cascades to `provider_audit_logs` (FK ON DELETE CASCADE).
Sets `ai_usage_logs.provider_config_id` to NULL.

**Response:** 204 No Content.
**Errors:** 404 `not_found`.

### `POST /api/admin/providers/{id}/test`

Run a connection test using the row's stored credentials. Writes the
result back to the row (status, latency, last_error, rate_limit_remaining).

**Response (200):** `HealthCheckResultSchema`:
```json
{
  "success": true,
  "status": "active",
  "latency_ms": 42,
  "error": null,
  "rate_limit": {"remaining": 5900, "limit": 6000, "reset_at": null, "retry_after_s": null, "source": "header:x-mbx-used-weight-1m"},
  "checked_at": "2026-06-16T12:00:00Z"
}
```

**Errors:** 404 `not_found`.

### `POST /api/admin/providers/test`

Ephemeral test. Body is `ProviderTestRequest` with plaintext credentials.
**Does not** write to the DB.

**Response (200):** `HealthCheckResultSchema` (same as above).
**Errors:** none (the request always returns 200 with a result, even on failure).

### `POST /api/admin/providers/{id}/enable`

Set `enabled=True`. Updates `status` (no longer "disabled").

**Response (200):** `ProviderConfigView`.
**Errors:** 404 `not_found`.

### `POST /api/admin/providers/{id}/disable`

Set `enabled=False`. Sets `status="disabled"`. The scheduler skips this row.

**Response (200):** `ProviderConfigView`.
**Errors:** 404 `not_found`.

### `POST /api/admin/providers/{id}/rotate-credentials`

**Reserved.** Returns 501 in this round. Will replace stored credentials
with a new value (e.g. for OAuth refresh flows). Implementation deferred.

**Response:** 501 `not_implemented`.

### `GET /api/admin/providers/{id}/audit-log?limit=50`

Lists the most recent N audit log entries for the provider, newest first.

**Response (200):**
```json
[
  {
    "id": 17,
    "action": "update",
    "actor": "api",
    "before_hash": "ab12cd34",
    "after_hash": "ef56gh78",
    "ip": "127.0.0.1",
    "created_at": "2026-06-16T12:00:00Z"
  },
  ...
]
```

### `GET /api/admin/providers/health-summary`

Aggregate counts across all providers.

**Response (200):**
```json
{
  "by_category": {"llm": 3, "cex": 2, "notification": 1, ...},
  "total_active": 4,
  "total_error": 2,
  "total_disabled": 0,
  "total_configured": 5,
  "total": 6,
  "checked_at": "2026-06-16T12:00:00Z"
}
```

### `POST /api/admin/providers/health-tick`

Manually trigger one scheduler tick. Useful for the "Test All" UI button.

**Response (200):** `{"tested": 5}` (number of providers tested).

## Error Code Reference

| Code | HTTP | When |
|---|---|---|
| `not_found` | 404 | row id does not exist |
| `duplicate` | 409 | unique-constraint violation |
| `unknown_provider` | 400 | provider_name not in registry |
| `invalid_payload` | 400 | Pydantic validation failed |
| `not_implemented` | 501 | endpoint reserved but not yet built |

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` §8
- Configuration model: `docs/settings/configuration-model.md`
- API audit (per-provider details): `docs/integrations/api-audit.md`
```

- [ ] **Step 2: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/backend/api-contracts.md && git commit -m "docs: backend/api-contracts (/api/admin/providers/* surface)"
```

---

### Task 4.4: `docs/database/schema-notes.md`

**Files:**
- Create: `docs/database/schema-notes.md`

- [ ] **Step 1: Write the file**

```markdown
# Database Schema Notes — Provider Adapter Foundation

ER overview and column-level documentation for the new `provider_configs`
and `provider_audit_logs` tables, plus the soft FK added to
`ai_usage_logs`.

## ER Diagram (text)

```
┌──────────────────────────────┐
│       provider_configs        │
│──────────────────────────────│
│ id              PK           │
│ category                     │
│ provider_name                │
│ instance_name                │
│ config (JSON)                │
│ credentials_ct               │  ← Fernet ciphertext
│ credentials_fields (JSON)    │
│ enabled, is_active           │
│ priority                     │
│ status, credential_status    │
│ last_sync_at, last_error     │
│ latency_ms                   │
│ rate_limit_remaining         │
│ rate_limit_reset_at          │
│ created_at, updated_at       │
└──────────────┬───────────────┘
               │ ON DELETE CASCADE
               ▼
┌──────────────────────────────┐
│     provider_audit_logs       │
│──────────────────────────────│
│ id              PK           │
│ provider_id       FK         │
│ action                       │
│ actor, ip                    │
│ before_hash, after_hash      │  ← SHA-256-8 of creds_ct
│ created_at                   │
└──────────────────────────────┘

┌──────────────────────────────┐        ┌──────────────────────────────┐
│       ai_usage_logs          │        │       provider_configs        │
│ (existing; +FK this round)   │        │                               │
│──────────────────────────────│        │                               │
│ id              PK           │        │                               │
│ provider        (existing)   │        │                               │
│ model           (existing)   │        │                               │
│ service         (existing)   │        │                               │
│ tokens_used     (existing)   │        │                               │
│ latency_ms      (existing)   │        │                               │
│ created_at      (existing)   │        │                               │
│ provider_config_id  FK-new   │──┐     │                               │
└──────────────────────────────┘  │     │                               │
                                  │  ON DELETE SET NULL              │
                                  └────→│ id PK                          │
                                        └──────────────────────────────┘
```

## `provider_configs` (new)

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | Integer | no | autoincrement | PK |
| `category` | String | no | — | one of 8 values |
| `provider_name` | String | no | — | matches a registered provider name |
| `instance_name` | String | yes | NULL | required for LLM; enforced NULL otherwise |
| `config` | JSON | no | `{}` | non-sensitive Pydantic-validated config |
| `credentials_ct` | Text | yes | NULL | Fernet-encrypted JSON of credentials dict |
| `credentials_fields` | JSON | yes | NULL | sorted list of credential dict keys |
| `enabled` | Boolean | no | `true` | admin on/off |
| `is_active` | Boolean | no | `false` | derived: `True iff status='active'` |
| `priority` | Integer | no | 0 | LLM routing priority |
| `status` | String | no | `'unknown'` | derived enum |
| `credential_status` | String | no | `'missing'` | `missing/configured/expired/invalid` |
| `last_sync_at` | DateTime | yes | NULL | last `test_connection` time |
| `last_error` | String | yes | NULL | truncated to 200 chars |
| `latency_ms` | Integer | yes | NULL | last test latency |
| `rate_limit_remaining` | Integer | yes | NULL | from response header |
| `rate_limit_reset_at` | DateTime | yes | NULL | from response header |
| `created_at` | DateTime | no | server now | |
| `updated_at` | DateTime | no | server now | on update |

### Constraints

- `ck_instance_name_by_category`:
  `(category = 'llm' AND instance_name IS NOT NULL) OR (category != 'llm' AND instance_name IS NULL)`

### Indices

- `ix_provider_config_category` (`category`)
- `ix_provider_config_provider_name` (`provider_name`)
- `ix_provider_config_cat_name` (composite: `category`, `provider_name`)
- `ix_provider_config_enabled` (`enabled`)

### Uniqueness

Enforced at the service layer (`ProviderConfigService.upsert`):

- LLM: `WHERE category = ? AND provider_name = ? AND instance_name = ?`
- Other: `WHERE category = ? AND provider_name = ? AND instance_name IS NULL`

A hit raises `DuplicateProviderError` → HTTP 409 `code="duplicate"`.

**Why not a DB-level unique constraint?** SQLAlchemy/PostgreSQL partial
unique indexes have DB-vendor-specific syntax that complicates the
SQLite dev path. The CheckConstraint guarantees that the search
predicate finds only valid candidates, so the service-layer check is
race-free under SERIALIZABLE isolation (and acceptable under READ
COMMITTED for this dev-phase product).

## `provider_audit_logs` (new)

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | Integer | no | autoincrement | PK |
| `provider_id` | Integer | no | — | FK to `provider_configs.id` ON DELETE CASCADE |
| `action` | String | no | — | `create/update/enable/disable/test/rotate/delete` |
| `actor` | String | yes | NULL | who triggered (`api`/`cli`/etc) |
| `before_hash` | String | yes | NULL | SHA-256-8 of pre-state `credentials_ct` |
| `after_hash` | String | yes | NULL | SHA-256-8 of post-state `credentials_ct` |
| `ip` | String | yes | NULL | client IP from request |
| `created_at` | DateTime | no | server now | indexed |

### Indices

- `ix_provider_audit_logs_provider_id` (`provider_id`)
- `ix_provider_audit_logs_created_at` (`created_at`)

## `ai_usage_logs` (existing, +FK)

A nullable `provider_config_id` FK is added. `ON DELETE SET NULL` so
deleting a config preserves historical usage records.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `provider_config_id` | Integer | yes | FK to `provider_configs.id` ON DELETE SET NULL |

## `ai_provider_configs` (dropped)

The legacy table is dropped in this migration. It had:

| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | |
| `provider` | String | `openai/anthropic/ollama` |
| `api_key_encrypted` | String | Fernet-encrypted single key |
| `base_url` | String | |
| `model` | String | |
| `is_active` | Boolean | |
| `priority` | Integer | |
| `created_at`, `updated_at` | DateTime | |

It could not represent:
- Multi-instance LLM (one row per provider_name)
- Multi-category (CEX, notification, etc.)
- Rate-limit runtime state
- Audit log
- Provider enable/disable independent of is_active

## Alembic migration

File: `backend/alembic/versions/2026_06_16_xxxx_provider_foundation.py`

Order of operations:

1. Add nullable `provider_config_id` to `ai_usage_logs` + FK.
2. Create `provider_configs` + indices.
3. Create `provider_audit_logs` + indices.
4. Drop `ai_provider_configs`.

The `downgrade` reverses in opposite order. The migration is not
data-preserving — the dev environment accepts that.

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md` §6
- API contracts: `docs/backend/api-contracts.md`
- Configuration model: `docs/settings/configuration-model.md`
```

- [ ] **Step 2: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add docs/database/schema-notes.md && git commit -m "docs: database/schema-notes (provider_configs + provider_audit_logs + drop)"
```

---

## PR 5: Wrap-up

### Task 5.1: Run full pytest, ensure ≥ 30% coverage

**Files:** none

- [ ] **Step 1: Run the test suite**

```bash
cd /Users/novspace/workspace/phosphor-terminal/backend && python3 -m pytest tests/ -q --cov=app
```

Expected: all tests pass; coverage ≥ 30%.

- [ ] **Step 2: If coverage < 30%, add tests**

Add `tests/test_models_provider_config.py` and
`tests/test_schemas_provider_config.py` if needed.

- [ ] **Step 3: Commit any new test files**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add backend/tests/ && git commit -m "test: bring coverage to ≥ 30%"
```

---

### Task 5.2: Run swift build, confirm iOS compiles

- [ ] **Step 1: Build the macOS app**

```bash
cd /Users/novspace/workspace/phosphor-terminal/macos-app && swift build 2>&1 | tail -20
```

Expected: no errors.

- [ ] **Step 2: Fix any Codable/URL errors**

Refer to Task 3.9/3.10/3.11 for the target endpoints.

- [ ] **Step 3: Commit fixes if any**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add macos-app/ && git commit -m "fix(ios): resolve Codable/URL compile errors after API migration"
```

---

### Task 5.3: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add a section under "Backend (`backend/app/`)"**

Add:

> **Provider Adapter Foundation** (sub-project 1, 2026-06-16): New
> package `app/services/providers/` holds the `ProviderAdapter` Protocol,
> `ProviderRegistry`, `ProviderConfigService`, `ProviderHealthService`,
> and `ProviderHealthScheduler` (native asyncio). All 8 provider
> categories (`llm/cex/dex/notification/market_data/onchain/social/news`)
> register their adapters at import time. Admin API: `/api/admin/providers/*`.
> Configuration persists in the `provider_configs` table; credentials are
> Fernet-encrypted. See `docs/integrations/api-audit.md` for per-provider
> integration details and `docs/settings/configuration-model.md` for the
> configuration schema. Dropped files: `services/data_source_manager.py`,
> `routers/data_source_bff.py`, `ai_provider_configs` table.

- [ ] **Step 2: Update the "Conventions" section**

Add a bullet:

> - **ProviderAdapter**: New domain types under `app/services/providers/`. New API endpoint → register a `ProviderAdapter` subclass + add to the category's `__init__.py`. Health/test/scheduler handle the rest.

- [ ] **Step 3: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add CLAUDE.md && git commit -m "docs: update CLAUDE.md with Provider Adapter Foundation section"
```

---

### Task 5.4: Update `README.md`

- [ ] **Step 1: Add a paragraph near the architecture overview**

> Provider integrations go through a unified Provider Adapter framework
> (`backend/app/services/providers/`). Configuration is stored in the
> `provider_configs` table; the admin API is at `/api/admin/providers/*`.
> See `docs/integrations/api-audit.md` for per-provider integration
> details and `docs/settings/configuration-model.md` for the configuration
> schema.

- [ ] **Step 2: Commit**

```bash
cd /Users/novspace/workspace/phosphor-terminal && git add README.md && git commit -m "docs: README mentions Provider Adapter Foundation"
```

---

## Self-Review (for the implementer, before claiming done)

- [ ] Every new Python file imports cleanly
- [ ] `pytest tests/ -q` green; coverage ≥ 30%
- [ ] `swift build` green
- [ ] `curl http://localhost:8000/api/admin/providers/categories` returns 8 categories
- [ ] `POST /api/admin/providers` with a test OpenAI key creates a row whose `credentials_ct` is not the plaintext
- [ ] After 60s, scheduler has logged a tick and updated `last_sync_at`
- [ ] `GET /api/admin/providers/1/audit-log` shows the expected actions
- [ ] Setting `provider_health_enabled=false` in `.env` suppresses scheduler logs

## Cross-references

- Spec: `docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md`
- API audit: `docs/integrations/api-audit.md`
- Configuration model: `docs/settings/configuration-model.md`
- API contracts: `docs/backend/api-contracts.md`
- Database notes: `docs/database/schema-notes.md`

**End of plan.**
