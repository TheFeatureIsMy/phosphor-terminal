"""Build a self-contained Freqtrade config for a tenant runtime."""
from __future__ import annotations

from typing import Any

from app.schemas.live_small import CapitalPoolParams
from app.services.live_small.config_generator import (
    ccxt_spot_api_urls,
    generate_config_preview,
)


def build_tenant_runtime_config(
    dsl: dict[str, Any],
    pool: CapitalPoolParams,
    *,
    tenant_id: int,
    dry_run: bool = True,
    max_open_trades_cap: int | None = None,
    api_port: int = 8080,
    api_username: str = "freqtrade",
    api_password: str = "freqtrade",
    exchange_key: str = "",
    exchange_secret: str = "",
) -> dict[str, Any]:
    preview = generate_config_preview(
        dsl, pool, max_open_trades_cap=max_open_trades_cap,
    )
    urls = ccxt_spot_api_urls("demo" if dry_run else "live")
    return {
        "dry_run": dry_run,
        "trading_mode": "spot",
        "stake_currency": preview.stake_currency,
        "stake_amount": preview.stake_amount,
        "max_open_trades": preview.max_open_trades,
        "stoploss": preview.stoploss,
        "trailing_stop": preview.trailing_stop,
        "timeframe": str(dsl.get("timeframe") or "15m"),
        "db_url": f"sqlite:////data/tenants/{tenant_id}/tradesv3.sqlite",
        "user_data_dir": f"/data/tenants/{tenant_id}",
        "exchange": {
            "name": preview.exchange_name,
            "key": exchange_key,
            "secret": exchange_secret,
            "ccxt_config": {
                "enableRateLimit": True,
                "options": {"defaultType": "spot"},
                "urls": {"api": urls},
            },
            "pair_whitelist": preview.pair_whitelist or ["BTC/USDT"],
            "pair_blacklist": [],
        },
        "pairlists": [{"method": "StaticPairList"}],
        "protections": list(preview.protections),
        "api_server": {
            "enabled": True,
            "listen_ip_address": "0.0.0.0",
            "listen_port": api_port,
            "verbosity": "error",
            "enable_openapi": False,
            "jwt_secret_key": f"alphaloop-tenant-{tenant_id}",
            "CORS_origins": [],
            "username": api_username,
            "password": api_password,
        },
        "initial_state": "running",
        "bot_name": f"alphaloop-tenant-{tenant_id}",
        "cancel_open_orders_on_exit": True,
    }
