"""Tests for the Discord notification adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.notification.discord import DiscordProvider


@pytest.mark.asyncio
async def test_204_returns_active():
    a = DiscordProvider()
    with patch("app.services.providers.categories.notification.discord.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 204
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.head = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"webhook_url": "https://discord.com/api/webhooks/123/abc"},
            {"timeout_s": 5.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_404_returns_inactive():
    a = DiscordProvider()
    with patch("app.services.providers.categories.notification.discord.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 404
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.head = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"webhook_url": "https://discord.com/api/webhooks/123/deleted"},
            {"timeout_s": 5.0},
        )
    assert r.status == ProviderStatus.INACTIVE


@pytest.mark.asyncio
async def test_missing_webhook_url_returns_error():
    a = DiscordProvider()
    r = await a.test_connection({}, {"timeout_s": 5.0})
    assert r.success is False
    assert "webhook_url" in (r.error or "")


def test_meta():
    a = DiscordProvider()
    assert a.provider_name == "discord"
    assert a.category == ProviderCategory.NOTIFICATION
    assert a.is_multi_instance is False
