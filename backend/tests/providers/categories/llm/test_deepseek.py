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
