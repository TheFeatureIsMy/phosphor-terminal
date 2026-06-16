"""Tests for the Webhook notification adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.notification.webhook import WebhookProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = WebhookProvider()
    with patch("app.services.providers.categories.notification.webhook.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 200
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        session.post = MagicMock(return_value=resp)
        r = await a.test_connection(
            {"auth_header": "Bearer xyz"},
            {"url": "https://example.com/webhook", "timeout_s": 5.0},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_500_returns_error():
    a = WebhookProvider()
    with patch("app.services.providers.categories.notification.webhook.aiohttp.ClientSession") as M:
        session = MagicMock()
        M.return_value.__aenter__ = AsyncMock(return_value=session)
        M.return_value.__aexit__ = AsyncMock(return_value=None)
        resp = MagicMock()
        resp.status = 500
        resp.__aenter__ = AsyncMock(return_value=resp)
        resp.__aexit__ = AsyncMock(return_value=None)
        resp.text = AsyncMock(return_value="server error")
        session.post = MagicMock(return_value=resp)
        r = await a.test_connection(
            {},
            {"url": "https://example.com/webhook", "timeout_s": 5.0},
        )
    assert r.success is False
    assert r.status == ProviderStatus.ERROR


def test_meta():
    a = WebhookProvider()
    assert a.provider_name == "webhook"
    assert a.category == ProviderCategory.NOTIFICATION
    assert a.is_multi_instance is False
