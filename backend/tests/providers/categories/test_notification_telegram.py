"""Tests for the Telegram notification adapter."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderStatus
from app.services.providers.categories.notification.telegram import TelegramProvider


@pytest.mark.asyncio
async def test_missing_creds_returns_error():
    a = TelegramProvider()
    r = await a.test_connection({}, {"dry_run": True})
    assert r.status == ProviderStatus.ERROR
    assert "bot_token" in r.error


@pytest.mark.asyncio
async def test_dry_run_succeeds():
    a = TelegramProvider()
    r = await a.test_connection(
        {"bot_token": "x", "chat_id": "1"}, {"dry_run": True},
    )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_live_200_returns_active():
    a = TelegramProvider()
    with patch("app.services.providers.categories.notification.telegram.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.get = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"bot_token": "x", "chat_id": "1"}, {"dry_run": False},
        )
    assert r.success is True
