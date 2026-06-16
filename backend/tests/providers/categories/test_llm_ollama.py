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
