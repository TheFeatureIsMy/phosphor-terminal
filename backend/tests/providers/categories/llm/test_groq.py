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
