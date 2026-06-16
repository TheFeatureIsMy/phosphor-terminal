"""Tests for the CryptoCompare Social adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.social.cryptocompare_social import CryptoCompareSocialProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = CryptoCompareSocialProvider()
    with patch("app.services.providers.categories.social.cryptocompare_social.aiohttp.ClientSession") as M:
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
            {}, {"base_url": "https://min-api.cryptocompare.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = CryptoCompareSocialProvider()
    with patch("app.services.providers.categories.social.cryptocompare_social.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 500
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="server error")
        resp.headers = {}
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {}, {"base_url": "https://min-api.cryptocompare.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = CryptoCompareSocialProvider()
    assert a.provider_name == "cryptocompare_social"
    assert a.category == ProviderCategory.SOCIAL
    assert a.is_multi_instance is False
