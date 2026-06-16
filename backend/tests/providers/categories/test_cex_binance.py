"""Tests for the Binance CEX adapter."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderStatus
from app.services.providers.categories.cex.binance import BinanceProvider


@pytest.mark.asyncio
async def test_200_returns_active_with_rate_limit():
    a = BinanceProvider()
    with patch("app.services.providers.categories.cex.binance.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.headers = {"X-MBX-USED-WEIGHT-1M": "100"}
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection({}, {"base_url": "https://api.binance.com"})
    assert r.success is True
    assert r.rate_limit is not None
    assert r.rate_limit.remaining == 6000 - 100


def test_meta():
    a = BinanceProvider()
    assert a.provider_name == "binance"
    assert a.is_multi_instance is False
