"""Tests for the Gemini (Google AI Studio) LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.gemini import GeminiProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = GeminiProvider()
    with patch("app.services.providers.categories.llm.gemini.aiohttp.ClientSession") as M:
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
            {"api_key": "AIza-test"},
            {"base_url": "https://generativelanguage.googleapis.com", "model": "gemini-1.5-flash"},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_403_returns_inactive():
    a = GeminiProvider()
    with patch("app.services.providers.categories.llm.gemini.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 403
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="permission denied")
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"api_key": "bad"},
            {"base_url": "https://generativelanguage.googleapis.com", "model": "gemini-1.5-flash"},
        )
    assert r.status == ProviderStatus.INACTIVE


@pytest.mark.asyncio
async def test_missing_api_key_returns_error():
    a = GeminiProvider()
    r = await a.test_connection(
        {}, {"base_url": "https://generativelanguage.googleapis.com", "model": "gemini-1.5-flash"},
    )
    assert r.success is False
    assert "api_key" in (r.error or "").lower()


def test_meta():
    a = GeminiProvider()
    assert a.provider_name == "gemini"
    assert a.category == ProviderCategory.LLM
    assert a.is_multi_instance is True
