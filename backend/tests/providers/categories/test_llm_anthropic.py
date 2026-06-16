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
