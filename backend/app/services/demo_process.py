"""Read the simulation process. Never returns API keys."""
from __future__ import annotations

import json
from pathlib import Path

from app.schemas.trading import DemoProcessResponse

_DEMO_CONFIG = Path(__file__).resolve().parents[3] / "freqtrade" / "user_data" / "config.demo.json"


def demo_venue() -> tuple[str, list[str]]:
    try:
        cfg = json.loads(_DEMO_CONFIG.read_text())
    except (OSError, json.JSONDecodeError):
        return "freqtrade", []
    urls = ((cfg.get("exchange") or {}).get("ccxt_config") or {}).get("urls", {}).get("api") or {}
    hosts = [str(urls[name]) for name in ("public", "private", "v1") if urls.get(name)]
    if any("demo-api.binance.com" in host for host in hosts):
        return "binance_demo", hosts
    return "freqtrade", hosts


async def read_demo_process() -> DemoProcessResponse:
    from app.services.freqtrade_client import FreqtradeClient

    venue, hosts = demo_venue()
    client = FreqtradeClient()
    if not await client.ping():
        return DemoProcessResponse(reachable=False, state="unreachable", venue=venue, rest_hosts=hosts)

    cfg = await client.get_show_config()
    count = await client.get_count()
    trades = await client.get_trades()
    balance = await client.get_balance()
    if not FreqtradeClient.is_success(cfg):
        return DemoProcessResponse(reachable=False, state="unreachable", venue=venue, rest_hosts=hosts)

    balances = []
    for row in (balance.get("currencies") or []) if FreqtradeClient.is_success(balance) else []:
        amount = float(row.get("balance") or 0)
        if amount:
            balances.append({"currency": row.get("currency") or "", "balance": amount})
    open_trades = int(count.get("current") or 0) if FreqtradeClient.is_success(count) else 0
    closed = 0
    if FreqtradeClient.is_success(trades):
        closed = int(trades.get("total_trades") or trades.get("trades_count") or 0)
    total = None
    if FreqtradeClient.is_success(balance) and balance.get("total") is not None:
        total = float(balance["total"])
    return DemoProcessResponse(
        reachable=True,
        state=str(cfg.get("state") or "running"),
        strategy=cfg.get("strategy"),
        timeframe=cfg.get("timeframe"),
        trading_mode=cfg.get("trading_mode"),
        dry_run=cfg.get("dry_run"),
        exchange=cfg.get("exchange"),
        venue=venue,
        rest_hosts=hosts,
        stake_currency=cfg.get("stake_currency"),
        stake_amount=None if cfg.get("stake_amount") is None else str(cfg.get("stake_amount")),
        max_open_trades=cfg.get("max_open_trades"),
        open_trades=open_trades,
        closed_trades=closed,
        total=total,
        balances=balances,
    )
