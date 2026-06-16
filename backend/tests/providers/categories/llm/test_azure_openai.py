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
