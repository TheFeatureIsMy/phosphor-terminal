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
