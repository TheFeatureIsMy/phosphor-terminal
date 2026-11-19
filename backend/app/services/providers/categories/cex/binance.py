"""Binance CEX adapter. Real implementation using public API."""
from __future__ import annotations

import hashlib
import hmac
import json
import time

import aiohttp
from pydantic import BaseModel, Field

from app.services.providers.base import (
    HealthCheckResult, ProviderCategory, ProviderStatus, RateLimitInfo,
)
from app.services.providers.runtime import RateLimitParser
from app.services.system_trust import client_ssl_context


class BinanceConfig(BaseModel):
    base_url: str = Field(default="https://api.binance.com/api")
    timeout_s: float = Field(default=10.0)


# Official Spot REST bases. Demo mode replaces the live /api host; the two
# must never be mixed. Withdrawal endpoints are not part of this adapter.
DEMO_REST_BASE = "https://demo-api.binance.com/api"
LIVE_REST_BASE = "https://api.binance.com/api"
PRIVATE_ROUTES = ("v3/account",)
CONFIRM_PHRASE = "I confirm live trading"


def rest_base_for_mode(mode: str) -> str:
    """Return the official Spot REST base for demo or live. Never the other host."""
    if mode == "demo":
        return DEMO_REST_BASE
    if mode == "live":
        return LIVE_REST_BASE
    raise ValueError(f"unknown binance mode: {mode}")


def ccxt_spot_api_urls(mode: str) -> dict[str, str]:
    """Spot slice of the ccxt Binance URL map for one mode.

    ccxt's ``enable_demo_trading(True)`` replaces ``urls['api']`` with
    ``urls['demo']``, including ``public``, ``private``, and ``v1``. Freqtrade
    never calls that method, and a partial override leaves ``v1`` on the live
    host. Callers must set all three.
    """
    base = rest_base_for_mode(mode)
    return {
        "public": f"{base}/v3",
        "private": f"{base}/v3",
        "v1": f"{base}/v1",
    }


def sign_payload(payload: str, secret: str) -> str:
    """HMAC-SHA256 hex signature for a Spot query string. Payload is case-sensitive."""
    return hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()


def private_route(name: str) -> str:
    """Allow only account reads. Withdrawal is refused."""
    if "withdraw" in name.lower():
        raise ValueError("withdraw is not available")
    if name not in ("account", "v3/account"):
        raise ValueError(f"unsupported private route: {name}")
    return "v3/account"


def rest_url(base: str, route: str) -> str:
    """Join a Spot REST base with a route such as v3/ping.

    Official demo mode replaces https://api.binance.com/api with
    https://demo-api.binance.com/api. Older saved configs omit the /api suffix.
    """
    root = base.rstrip("/")
    path = route.lstrip("/")
    if root.endswith("/api"):
        return f"{root}/{path}"
    return f"{root}/api/{path}"


class BinanceProvider:
    category = ProviderCategory.CEX
    provider_name = "binance"
    is_multi_instance = False
    config_schema = BinanceConfig

    async def test_connection(self, credentials, config):
        cfg = self.config_schema.model_validate(config)
        base = cfg.base_url.rstrip("/")
        api_key = str((credentials or {}).get("api_key") or "").strip()
        api_secret = str((credentials or {}).get("api_secret") or "").strip()
        headers = None
        if api_key and api_secret:
            query = f"timestamp={int(time.time() * 1000)}&recvWindow=5000"
            signature = sign_payload(query, api_secret)
            url = rest_url(base, f"{private_route('account')}?{query}&signature={signature}")
            headers = {"X-MBX-APIKEY": api_key}
        else:
            url = rest_url(base, "v3/ping")
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        start = time.monotonic()
        try:
            connector = aiohttp.TCPConnector(ssl=client_ssl_context())
            async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
                async with session.get(url, headers=headers) as resp:
                    latency = int((time.monotonic() - start) * 1000)
                    rl = RateLimitParser.parse(dict(resp.headers))
                    if resp.status == 200:
                        return HealthCheckResult(success=True, status=ProviderStatus.ACTIVE, latency_ms=latency, rate_limit=rl)
                    text = await resp.text()
                    return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=latency, error=f"HTTP {resp.status}: {text[:120]}", rate_limit=rl)
        except Exception as exc:
            return HealthCheckResult(success=False, status=ProviderStatus.ERROR, latency_ms=None, error=str(exc)[:200])

    async def read_account(self, credentials, config) -> dict:
        """Signed Spot account read. Returns balances only, never the key."""
        cfg = self.config_schema.model_validate(config)
        api_key = str((credentials or {}).get("api_key") or "").strip()
        api_secret = str((credentials or {}).get("api_secret") or "").strip()
        if not api_key or not api_secret:
            return {"ok": False, "error": "missing demo credentials"}
        query = f"timestamp={int(time.time() * 1000)}&recvWindow=5000"
        signature = sign_payload(query, api_secret)
        url = rest_url(cfg.base_url, f"{private_route('account')}?{query}&signature={signature}")
        if "demo-api.binance.com" not in url and "api.binance.com" not in url:
            return {"ok": False, "error": "refusing unknown host"}
        timeout = aiohttp.ClientTimeout(total=cfg.timeout_s)
        connector = aiohttp.TCPConnector(ssl=client_ssl_context())
        async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
            async with session.get(url, headers={"X-MBX-APIKEY": api_key}) as resp:
                text = await resp.text()
                if resp.status != 200:
                    return {"ok": False, "status": resp.status, "error": text[:180]}
                payload = json.loads(text)
        balances = [
            {"asset": row.get("asset"), "free": row.get("free"), "locked": row.get("locked")}
            for row in payload.get("balances") or []
            if float(row.get("free") or 0) or float(row.get("locked") or 0)
        ]
        return {"ok": True, "host": "demo" if "demo-api.binance.com" in url else "live", "balances": balances}

    async def fetch_rate_limit(self, credentials, config):
        return None

    def mask_config(self, config):
        return dict(config)
