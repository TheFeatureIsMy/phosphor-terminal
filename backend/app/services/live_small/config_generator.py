"""Freqtrade config generator — builds safe live_small config dict.

Generates a config dict with mandatory safety fields. Does NOT write files
to disk or interact with Freqtrade/Docker. The caller is responsible for
persisting the config through the Command Bus deployment flow.
"""
from __future__ import annotations

from typing import Any, Literal

from app.schemas.live_small import CapitalPoolParams, FreqtradeConfigPreview

MANDATORY_PROTECTIONS = [
    {
        "method": "CooldownPeriod",
        "stop_duration_candles": 4,
    },
    {
        "method": "MaxDrawdown",
        "lookback_period_candles": 48,
        "max_allowed_drawdown": 0.03,
        "stop_duration_candles": 12,
    },
    {
        "method": "StoplossGuard",
        "lookback_period_candles": 24,
        "trade_limit": 3,
        "stop_duration_candles": 12,
    },
]


def generate_config_preview(
    dsl: dict[str, Any],
    pool: CapitalPoolParams,
    exchange_name: str = "binance",
) -> FreqtradeConfigPreview:
    risk = dsl.get("risk", {})
    stoploss = risk.get("stoploss", -0.05)
    if stoploss >= 0:
        stoploss = -0.05

    max_open_trades = min(
        risk.get("max_open_trades", 3),
        _max_trades_from_pool(pool),
    )
    if max_open_trades < 1:
        max_open_trades = 1

    stake_amount = round(pool.total_budget * pool.max_position_pct_per_trade, 2)
    if stake_amount * max_open_trades > pool.total_budget:
        stake_amount = round(pool.total_budget / max_open_trades, 2)

    symbols = dsl.get("symbols", [])
    trailing = risk.get("trailing_stop", False)

    return FreqtradeConfigPreview(
        dry_run=False,
        trading_mode="spot",
        stake_currency=pool.currency,
        stake_amount=stake_amount,
        tradable_balance_ratio=0.95,
        max_open_trades=max_open_trades,
        stoploss=stoploss,
        trailing_stop=trailing,
        exchange_name=exchange_name,
        pair_whitelist=symbols,
        protections=list(MANDATORY_PROTECTIONS),
        api_server_listen_ip="127.0.0.1",
    )


def validate_config_safety(config: FreqtradeConfigPreview, pool: CapitalPoolParams) -> list[str]:
    errors: list[str] = []

    if config.dry_run is not False:
        errors.append("dry_run must be False for live_small")
    if config.trading_mode != "spot":
        errors.append("trading_mode must be 'spot'")
    if config.stoploss >= 0:
        errors.append("stoploss must be negative")
    if config.stake_amount * config.max_open_trades > pool.total_budget * 1.01:
        errors.append(
            f"stake_amount ({config.stake_amount}) × max_open_trades ({config.max_open_trades}) "
            f"exceeds total_budget ({pool.total_budget})"
        )
    if config.api_server_listen_ip != "127.0.0.1":
        errors.append("api_server must listen on 127.0.0.1")
    if not config.protections:
        errors.append("protections must include MaxDrawdown and StoplossGuard")

    return errors


def _max_trades_from_pool(pool: CapitalPoolParams) -> int:
    if pool.max_position_pct_per_trade <= 0:
        return 1
    max_by_exposure = pool.max_total_exposure_pct / pool.max_position_pct_per_trade
    return max(1, int(max_by_exposure))
