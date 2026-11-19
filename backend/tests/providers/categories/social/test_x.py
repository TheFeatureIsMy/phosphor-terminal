"""Tests for the X social adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.social.x import XProvider


@pytest.mark.asyncio
async def test_missing_token_is_inactive():
    result = await XProvider().test_connection({}, {})
    assert result.success is False
    assert result.status == ProviderStatus.INACTIVE
    assert result.error == "missing bearer token"


@pytest.mark.asyncio
async def test_200_returns_active():
    adapter = XProvider()
    with patch("app.services.providers.categories.social.x.aiohttp.ClientSession") as session_cls:
        session = MagicMock()
        session_cls.return_value.__aenter__ = AsyncMock(return_value=session)
        session_cls.return_value.__aexit__ = AsyncMock(return_value=None)
        response = MagicMock()
        response.status = 200
        response.__aenter__ = AsyncMock(return_value=response)
        response.__aexit__ = AsyncMock(return_value=None)
        session.get = MagicMock(return_value=response)
        result = await adapter.test_connection(
            {"api_key": "token"},
            {"base_url": "https://api.x.com", "timeout_s": 10.0},
        )
    assert result.success is True
    assert result.status == ProviderStatus.ACTIVE
    headers = session.get.call_args.kwargs["headers"]
    assert headers["Authorization"] == "Bearer token"


@pytest.mark.asyncio
async def test_401_returns_inactive():
    adapter = XProvider()
    with patch("app.services.providers.categories.social.x.aiohttp.ClientSession") as session_cls:
        session = MagicMock()
        session_cls.return_value.__aenter__ = AsyncMock(return_value=session)
        session_cls.return_value.__aexit__ = AsyncMock(return_value=None)
        response = MagicMock()
        response.status = 401
        response.text = AsyncMock(return_value="unauthorized")
        response.__aenter__ = AsyncMock(return_value=response)
        response.__aexit__ = AsyncMock(return_value=None)
        session.get = MagicMock(return_value=response)
        result = await adapter.test_connection({"api_key": "bad"}, {})
    assert result.success is False
    assert result.status == ProviderStatus.INACTIVE


def test_identity():
    adapter = XProvider()
    assert adapter.category == ProviderCategory.SOCIAL
    assert adapter.provider_name == "x"
    assert adapter.is_multi_instance is False
