"""ProviderRegistry: in-process registry of ProviderAdapter classes."""
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
