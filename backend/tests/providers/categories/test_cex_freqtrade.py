"""Tests for the Freqtrade CEX adapter."""
import pytest

from app.services.providers.base import ProviderStatus
from app.services.providers.categories.cex.freqtrade import FreqtradeProvider


class _FakeClient:
    def __init__(self, *, ping_result):
        self._ping_result = ping_result

    async def ping(self):
        return self._ping_result


@pytest.mark.asyncio
async def test_ping_ok_returns_active():
    a = FreqtradeProvider(client_factory=lambda **kw: _FakeClient(ping_result=True))
    r = await a.test_connection({}, {"url": "http://x", "username": "u", "password": "p"})
    assert r.success is True
    assert r.status == ProviderStatus.ACTIVE


@pytest.mark.asyncio
async def test_ping_false_returns_error():
    a = FreqtradeProvider(client_factory=lambda **kw: _FakeClient(ping_result=False))
    r = await a.test_connection({}, {"url": "http://x", "username": "u", "password": "p"})
    assert r.success is False
    assert r.status == ProviderStatus.ERROR
