"""Tests for the Zhipu (智谱 GLM) LLM provider adapter."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderCategory, ProviderStatus
from app.services.providers.categories.llm.zhipu import ZhipuProvider


@pytest.mark.asyncio
async def test_200_returns_active():
    a = ZhipuProvider()
    with patch("app.services.providers.categories.llm.zhipu.aiohttp.ClientSession") as M:
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
            {"api_key": "sk-test"},
            {"base_url": "https://open.bigmodel.cn/api/paas/v4", "model": "glm-4"},
        )
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_401_returns_inactive():
    a = ZhipuProvider()
    with patch("app.services.providers.categories.llm.zhipu.aiohttp.ClientSession") as M:
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
            {"base_url": "https://open.bigmodel.cn/api/paas/v4", "model": "glm-4"},
        )
    assert r.status == ProviderStatus.INACTIVE


def test_meta():
    a = ZhipuProvider()
    assert a.provider_name == "zhipu"
    assert a.category == ProviderCategory.LLM
    assert a.is_multi_instance is True
