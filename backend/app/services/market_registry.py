from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Optional


@dataclass(frozen=True)
class MarketConstraints:
    market_id: str
    display_name: str
    trading_hours: list[str]
    settlement: str
    allow_short: bool
    daily_limit: Optional[float]
    min_lot_size: int
    allow_day_trading: bool
    commission_rate: float
    enabled: bool
    adapter: str


class MarketRegistry:
    def __init__(self) -> None:
        self._markets: dict[str, MarketConstraints] = {}

    def register(self, constraints: MarketConstraints) -> None:
        self._markets[constraints.market_id] = constraints

    def get(self, market_id: str) -> MarketConstraints:
        if market_id not in self._markets:
            raise ValueError(f"Market {market_id} is not registered")
        return self._markets[market_id]

    def list(self) -> list[dict]:
        return [asdict(item) for item in self._markets.values()]

    def validate(self, market_id: str, require_enabled: bool = False) -> MarketConstraints:
        constraints = self.get(market_id)
        if require_enabled and not constraints.enabled:
            raise ValueError(f"Market {market_id} is registered but disabled")
        return constraints


market_registry = MarketRegistry()
market_registry.register(
    MarketConstraints(
        market_id="crypto",
        display_name="Crypto",
        trading_hours=["24/7"],
        settlement="T+0",
        allow_short=True,
        daily_limit=None,
        min_lot_size=1,
        allow_day_trading=True,
        commission_rate=0.001,
        enabled=True,
        adapter="freqtrade_ccxt",
    )
)
market_registry.register(
    MarketConstraints(
        market_id="us_stock",
        display_name="US Stocks",
        trading_hours=["09:30-16:00 America/New_York"],
        settlement="T+1",
        allow_short=True,
        daily_limit=None,
        min_lot_size=1,
        allow_day_trading=False,
        commission_rate=0.0005,
        enabled=False,
        adapter="alpaca_disabled",
    )
)
market_registry.register(
    MarketConstraints(
        market_id="a_share",
        display_name="A-Share",
        trading_hours=["09:30-11:30 Asia/Shanghai", "13:00-15:00 Asia/Shanghai"],
        settlement="T+1",
        allow_short=False,
        daily_limit=0.10,
        min_lot_size=100,
        allow_day_trading=False,
        commission_rate=0.0003,
        enabled=False,
        adapter="joinquant_disabled",
    )
)
