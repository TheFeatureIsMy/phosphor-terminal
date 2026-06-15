"""On-chain data adapter (Layer C) — holder concentration, whale transfers, exchange flows."""
from __future__ import annotations

import random
from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class OnchainSnapshot:
    """Point-in-time on-chain data for a token."""
    timestamp: str = ""
    top_10_holder_pct: float = 0.0        # % of supply held by top 10 wallets
    top_50_holder_pct: float = 0.0        # % of supply held by top 50 wallets
    gini_coefficient: float = 0.0         # 0 = equal, 1 = maximally concentrated
    exchange_inflow_24h: float = 0.0      # USD value deposited to exchanges
    exchange_outflow_24h: float = 0.0     # USD value withdrawn from exchanges
    whale_transfer_count: int = 0         # large transfers (> threshold)
    new_holders_24h: int = 0              # new unique holders added
    dex_volume_24h: float = 0.0           # DEX trading volume in USD
    contract_interactions: int = 0        # smart contract calls (transfers, approvals)
    data_quality: float = 0.60

    def to_dict(self) -> dict:
        return self.__dict__.copy()


class OnchainAdapter(ABC):
    @abstractmethod
    def get_snapshot(self, symbol: str) -> OnchainSnapshot: ...

    @abstractmethod
    def get_history(self, symbol: str, limit: int = 30) -> list[OnchainSnapshot]: ...


class MockOnchainAdapter(OnchainAdapter):
    """Mock adapter generating realistic on-chain data with accumulation-then-dump pattern."""

    def get_snapshot(self, symbol: str) -> OnchainSnapshot:
        return OnchainSnapshot(
            top_10_holder_pct=random.uniform(30, 70),
            top_50_holder_pct=random.uniform(50, 85),
            gini_coefficient=random.uniform(0.5, 0.9),
            exchange_inflow_24h=random.uniform(50_000, 2_000_000),
            exchange_outflow_24h=random.uniform(50_000, 2_000_000),
            whale_transfer_count=random.randint(0, 20),
            new_holders_24h=random.randint(50, 5000),
            dex_volume_24h=random.uniform(100_000, 10_000_000),
            contract_interactions=random.randint(100, 10_000),
        )

    def get_history(self, symbol: str, limit: int = 30) -> list[OnchainSnapshot]:
        snapshots = []
        # Starting state
        top_10 = random.uniform(25, 35)
        top_50 = top_10 + random.uniform(15, 25)
        gini = random.uniform(0.45, 0.55)
        exchange_inflow = random.uniform(100_000, 300_000)
        exchange_outflow = random.uniform(100_000, 300_000)
        whale_count = random.randint(1, 5)
        new_holders = random.randint(100, 500)

        for i in range(limit):
            phase = i / limit

            if phase < 0.4:
                # Accumulation phase: concentration increasing, outflow > inflow
                top_10 += random.uniform(0.3, 1.2)
                top_50 += random.uniform(0.2, 0.8)
                gini += random.uniform(0.005, 0.015)
                exchange_outflow *= (1 + random.uniform(0.02, 0.08))
                exchange_inflow *= (1 + random.uniform(-0.02, 0.02))
                whale_count = max(1, whale_count + random.randint(0, 2))
                new_holders = max(50, int(new_holders * random.uniform(0.9, 1.05)))
            elif phase < 0.7:
                # Hype phase: new holders surge (retail FOMO), whale activity high
                top_10 += random.uniform(0.1, 0.5)
                top_50 += random.uniform(0.1, 0.3)
                gini += random.uniform(0, 0.005)
                exchange_outflow *= (1 + random.uniform(0, 0.03))
                exchange_inflow *= (1 + random.uniform(0.01, 0.05))
                whale_count = max(2, whale_count + random.randint(0, 3))
                new_holders = int(new_holders * random.uniform(1.1, 1.4))
            else:
                # Pre-dump: sudden exchange inflow spike (whales depositing to sell)
                top_10 -= random.uniform(0.1, 0.5)
                top_50 -= random.uniform(0.1, 0.3)
                gini -= random.uniform(0, 0.005)
                exchange_inflow *= (1 + random.uniform(0.1, 0.3))
                exchange_outflow *= (1 + random.uniform(-0.05, 0.02))
                whale_count = max(3, whale_count + random.randint(1, 4))
                new_holders = max(50, int(new_holders * random.uniform(0.8, 1.0)))

            # Clamp values
            top_10 = max(10, min(90, top_10))
            top_50 = max(top_10 + 5, min(95, top_50))
            gini = max(0.1, min(0.99, gini))
            exchange_inflow = max(10_000, exchange_inflow)
            exchange_outflow = max(10_000, exchange_outflow)

            snapshots.append(OnchainSnapshot(
                timestamp=f"T-{limit - i}",
                top_10_holder_pct=top_10,
                top_50_holder_pct=top_50,
                gini_coefficient=gini,
                exchange_inflow_24h=exchange_inflow,
                exchange_outflow_24h=exchange_outflow,
                whale_transfer_count=max(0, whale_count),
                new_holders_24h=max(0, new_holders),
                dex_volume_24h=random.uniform(100_000, 5_000_000),
                contract_interactions=random.randint(200, 8_000),
            ))

        return snapshots
