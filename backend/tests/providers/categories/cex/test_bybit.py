"""Tests for the Bybit CEX adapter."""
from __future__ import annotations

import os
import sys
from unittest.mock import AsyncMock, MagicMock, patch

# --noconftest removes the project conftest that adds this to sys.path
BACKEND_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "..", "..")
)
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.cex.bybit import BybitProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = BybitProvider()
    with patch("app.services.providers.categories.cex.bybit.aiohttp.ClientSession") as M:
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
            {"api_key": "test", "secret": "test"},
            {"base_url": "https://api.bybit.com", "timeout_s": 10.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = BybitProvider()
    with patch("app.services.providers.categories.cex.bybit.aiohttp.ClientSession") as M:
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
            {"api_key": "test", "secret": "test"},
            {"base_url": "https://api.bybit.com", "timeout_s": 10.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = BybitProvider()
    assert a.provider_name == "bybit"
    assert a.category == ProviderCategory.CEX
    assert a.is_multi_instance is False
