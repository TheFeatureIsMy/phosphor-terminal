"""Cross-market data adapter (Layer E) — funding rate, OI, basis, liquidations."""
from __future__ import annotations

import math
import random
from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class CrossMarketSnapshot:
    """Point-in-time cross-market data for a symbol."""
    timestamp: str = ""
    spot_price: float = 0.0
    perpetual_price: float = 0.0
    basis: float = 0.0                    # spot - perp (or perp - spot depending on convention)
    basis_pct: float = 0.0                # basis as percentage of spot
    funding_rate: float = 0.0             # current funding rate (e.g., 0.01 = 1%)
    predicted_funding_rate: float = 0.0
    open_interest: float = 0.0            # total OI in USD
    oi_change_24h_pct: float = 0.0
    long_short_ratio: float = 1.0
    top_trader_long_short: float = 1.0
    liquidation_24h_long: float = 0.0     # USD value
    liquidation_24h_short: float = 0.0
    data_quality: float = 0.85

    def to_dict(self) -> dict:
        return {
            "spot_price": self.spot_price,
            "perpetual_price": self.perpetual_price,
            "basis": self.basis,
            "basis_pct": self.basis_pct,
            "funding_rate": self.funding_rate,
            "predicted_funding_rate": self.predicted_funding_rate,
            "open_interest": self.open_interest,
            "oi_change_24h_pct": self.oi_change_24h_pct,
            "long_short_ratio": self.long_short_ratio,
            "top_trader_long_short": self.top_trader_long_short,
            "liquidation_24h_long": self.liquidation_24h_long,
            "liquidation_24h_short": self.liquidation_24h_short,
            "data_quality": self.data_quality,
        }


class CrossMarketAdapter(ABC):
    @abstractmethod
    def get_snapshot(self, symbol: str) -> CrossMarketSnapshot:
        """Get current cross-market snapshot for a symbol."""
        ...

    @abstractmethod
    def get_history(self, symbol: str, limit: int = 100) -> list[CrossMarketSnapshot]:
        """Get historical cross-market snapshots."""
        ...


class MockCrossMarketAdapter(CrossMarketAdapter):
    """Mock adapter generating realistic cross-market data with manipulation scenarios."""

    def get_snapshot(self, symbol: str) -> CrossMarketSnapshot:
        base_price = self._base_price(symbol)
        # Simulate slight basis and normal funding
        basis_pct = random.gauss(0.001, 0.003)
        funding = random.gauss(0.0001, 0.0005)
        oi = base_price * random.uniform(500_000, 5_000_000)

        return CrossMarketSnapshot(
            spot_price=base_price,
            perpetual_price=base_price * (1 + basis_pct),
            basis=base_price * basis_pct,
            basis_pct=basis_pct * 100,
            funding_rate=funding,
            predicted_funding_rate=funding * random.uniform(0.8, 1.5),
            open_interest=oi,
            oi_change_24h_pct=random.gauss(0, 5),
            long_short_ratio=random.uniform(0.8, 1.3),
            top_trader_long_short=random.uniform(0.7, 1.5),
            liquidation_24h_long=oi * random.uniform(0, 0.02),
            liquidation_24h_short=oi * random.uniform(0, 0.02),
        )

    def get_history(self, symbol: str, limit: int = 100) -> list[CrossMarketSnapshot]:
        snapshots = []
        base_price = self._base_price(symbol)
        funding = 0.0001
        oi = base_price * 2_000_000

        for i in range(limit):
            # Simulate gradual buildup → squeeze → crash pattern
            phase = i / limit
            if phase < 0.3:
                # Normal period
                drift = random.gauss(0, 0.002)
                funding += random.gauss(0, 0.00005)
                oi *= (1 + random.gauss(0.001, 0.005))
            elif phase < 0.5:
                # Buildup: OI rising, funding going extreme
                drift = random.gauss(0.003, 0.002)
                funding += abs(random.gauss(0.0002, 0.0001))
                oi *= (1 + random.uniform(0.01, 0.03))
            elif phase < 0.65:
                # Squeeze: price spike, massive liquidations
                drift = random.gauss(0.01, 0.005)
                funding = max(funding, 0.003) + random.uniform(0, 0.002)
                oi *= (1 - random.uniform(0.02, 0.05))  # OI drops from liquidations
            elif phase < 0.8:
                # Crash: sharp reversal
                drift = random.gauss(-0.015, 0.005)
                funding -= abs(random.gauss(0.001, 0.0005))
                oi *= (1 - random.uniform(0.03, 0.08))
            else:
                # Aftermath: settling
                drift = random.gauss(-0.002, 0.003)
                funding = random.gauss(0, 0.0003)
                oi *= (1 + random.gauss(0, 0.01))

            base_price *= (1 + drift)
            basis_pct = random.gauss(0.001, 0.003) + (funding * 10)

            snapshots.append(CrossMarketSnapshot(
                timestamp=f"T-{limit - i}",
                spot_price=base_price,
                perpetual_price=base_price * (1 + basis_pct),
                basis=base_price * basis_pct,
                basis_pct=basis_pct * 100,
                funding_rate=funding,
                predicted_funding_rate=funding * random.uniform(0.9, 1.3),
                open_interest=max(0, oi),
                oi_change_24h_pct=random.gauss(0, 8),
                long_short_ratio=max(0.3, min(3.0, 1.0 + random.gauss(0, 0.2))),
                top_trader_long_short=max(0.3, min(3.0, 1.0 + random.gauss(0, 0.3))),
                liquidation_24h_long=max(0, oi * random.uniform(0, 0.03)),
                liquidation_24h_short=max(0, oi * random.uniform(0, 0.03)),
            ))

        return snapshots

    def _base_price(self, symbol: str) -> float:
        prices = {"BTC": 68000, "ETH": 3700, "SOL": 170, "AVAX": 38, "DOGE": 0.15, "PEPE": 0.000012}
        for prefix, price in prices.items():
            if prefix in symbol.upper():
                return price * random.uniform(0.95, 1.05)
        return 100.0
