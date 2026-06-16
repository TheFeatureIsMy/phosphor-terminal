"""LLMService — thin facade that selects a provider via ProviderRegistry.

Sub-project 1 of the Provider Adapter Foundation.

Backward-compat exports:
  - LLMResponse (dataclass, used by research pipeline callers)
  - create_llm_service_from_env (factory, used by ai_research router + rag_service)
"""
from __future__ import annotations

import logging
from typing import Any

from app.models.provider_config import ProviderConfig
from app.services.providers.base import ProviderCategory
from app.services.providers.config_service import ProviderConfigService
from app.services.providers.registry import registry

logger = logging.getLogger(__name__)


class LLMResponse:
    """Backward-compat response DTO used by research pipeline callers."""

    def __init__(
        self,
        content: str,
        model: str,
        provider: str,
        tokens_used: int = 0,
        latency_ms: float = 0,
    ) -> None:
        self.content = content
        self.model = model
        self.provider = provider
        self.tokens_used = tokens_used
        self.latency_ms = latency_ms


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
