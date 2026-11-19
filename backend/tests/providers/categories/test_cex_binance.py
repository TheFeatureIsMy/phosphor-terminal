"""Tests for the Binance CEX adapter."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.providers.base import ProviderStatus
from app.services.providers.categories.cex.binance import (
    DEMO_REST_BASE,
    LIVE_REST_BASE,
    BinanceProvider,
    ccxt_spot_api_urls,
    rest_base_for_mode,
    rest_url,
    sign_payload,
)


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


def test_hosts_are_not_mixed_and_hmac_matches_official_vector():
    assert rest_base_for_mode("demo") == DEMO_REST_BASE == "https://demo-api.binance.com/api"
    assert rest_base_for_mode("live") == LIVE_REST_BASE == "https://api.binance.com/api"
    assert "demo-api" not in rest_base_for_mode("live")
    assert "api.binance.com" not in rest_base_for_mode("demo").replace("demo-api.binance.com", "")
    payload = "symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559"
    secret = "NhqPtmdSJYdKjVHjA7PZj4Mge3R5YNiP1e3UZjInClVN65XAbvqqM6A7H5fATj0j"
    assert sign_payload(payload, secret) == "c8db56825ae71d6d79447849e617115f4a920fa2acdcab2b053c4b2838bd6b71"
    from app.services.providers.categories.cex.binance import private_route
    assert private_route("account") == "v3/account"
    try:
        private_route("withdraw")
    except ValueError as exc:
        assert "withdraw" in str(exc)
    else:
        raise AssertionError("withdraw must be refused")


def test_ccxt_spot_urls_include_v1_on_the_same_host():
    """ccxt enable_demo_trading replaces public, private, and v1 together."""
    demo = ccxt_spot_api_urls("demo")
    live = ccxt_spot_api_urls("live")
    assert demo == {
        "public": "https://demo-api.binance.com/api/v3",
        "private": "https://demo-api.binance.com/api/v3",
        "v1": "https://demo-api.binance.com/api/v1",
    }
    assert live == {
        "public": "https://api.binance.com/api/v3",
        "private": "https://api.binance.com/api/v3",
        "v1": "https://api.binance.com/api/v1",
    }
    assert "demo-api.binance.com" not in "".join(live.values())
    assert "https://api.binance.com" not in "".join(demo.values())
    partial = {"public": demo["public"], "private": demo["private"]}
    assert partial != demo


def test_demo_example_config_uses_the_full_spot_map():
    import json
    from pathlib import Path

    example = Path(__file__).resolve().parents[4] / "freqtrade/user_data/config.demo.example.json"
    cfg = json.loads(example.read_text())
    urls = cfg["exchange"]["ccxt_config"]["urls"]["api"]
    assert urls == ccxt_spot_api_urls("demo")
    assert "testnet.binance.vision" not in json.dumps(urls)
    assert cfg["dry_run"] is False
    assert cfg["trading_mode"] == "spot"


def test_demo_rest_base_matches_official_docs():
    official = "https://demo-api.binance.com/api/v3/ping"
    assert rest_url("https://demo-api.binance.com/api", "v3/ping") == official
    assert rest_url("https://demo-api.binance.com", "v3/ping") == official


def test_meta():
    a = BinanceProvider()
    assert a.provider_name == "binance"
    assert a.is_multi_instance is False
