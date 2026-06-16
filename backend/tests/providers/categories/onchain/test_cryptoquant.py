"""Tests for the CryptoQuant on-chain adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.onchain.cryptoquant import CryptoQuantProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = CryptoQuantProvider()
    with patch("app.services.providers.categories.onchain.cryptoquant.aiohttp.ClientSession") as M:
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
            {"api_key": "test-key"},
            {"base_url": "https://api.cryptoquant.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = CryptoQuantProvider()
    with patch("app.services.providers.categories.onchain.cryptoquant.aiohttp.ClientSession") as M:
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
            {"base_url": "https://api.cryptoquant.com", "timeout_s": 10.0},
        )
    assert r.status == ProviderStatus.INACTIVE


def test_meta():
    a = CryptoQuantProvider()
    assert a.provider_name == "cryptoquant"
    assert a.category == ProviderCategory.ONCHAIN
    assert a.is_multi_instance is False
