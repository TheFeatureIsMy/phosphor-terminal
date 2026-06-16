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
