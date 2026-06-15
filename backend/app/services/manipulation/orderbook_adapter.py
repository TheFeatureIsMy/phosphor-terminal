"""Orderbook data adapter (Layer B) — depth, large orders, cancel rates."""
from __future__ import annotations

import random
from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class OrderbookSnapshot:
    timestamp: str = ""
    bid_ask_spread: float = 0.0
    depth_1pct: float = 0.0           # total liquidity within 1% of mid
    depth_5pct: float = 0.0           # total liquidity within 5% of mid
    bid_depth_ratio: float = 0.5      # bid depth / total depth (0.5 = balanced)
    large_order_count: int = 0        # orders > 5x average size
    cancel_rate_5m: float = 0.0       # cancellation rate in last 5 min
    spoof_pattern_count: int = 0      # large orders placed then cancelled quickly
    liquidity_void_depth: float = 0.0 # largest gap in orderbook (% from mid)
    data_quality: float = 0.80

    def to_dict(self) -> dict:
        return self.__dict__.copy()


class OrderbookAdapter(ABC):
    @abstractmethod
    def get_snapshot(self, symbol: str) -> OrderbookSnapshot: ...

    @abstractmethod
    def get_history(self, symbol: str, limit: int = 60) -> list[OrderbookSnapshot]: ...


class MockOrderbookAdapter(OrderbookAdapter):
    def get_snapshot(self, symbol: str) -> OrderbookSnapshot:
        return OrderbookSnapshot(
            bid_ask_spread=random.uniform(0.01, 0.1),
            depth_1pct=random.uniform(50000, 500000),
            depth_5pct=random.uniform(200000, 2000000),
            bid_depth_ratio=random.uniform(0.35, 0.65),
            large_order_count=random.randint(0, 8),
            cancel_rate_5m=random.uniform(0, 0.4),
            spoof_pattern_count=random.randint(0, 3),
            liquidity_void_depth=random.uniform(0, 3.0),
        )

    def get_history(self, symbol: str, limit: int = 60) -> list[OrderbookSnapshot]:
        snapshots = []
        cancel_base = 0.1
        spoof_base = 0
        for i in range(limit):
            phase = i / limit
            # Simulate spoofing buildup
            if 0.3 < phase < 0.6:
                cancel_base = min(0.8, cancel_base + random.uniform(0.01, 0.05))
                spoof_base = min(10, spoof_base + random.uniform(0, 1))
            elif phase >= 0.6:
                cancel_base = max(0.1, cancel_base - random.uniform(0.01, 0.03))
                spoof_base = max(0, spoof_base - random.uniform(0, 0.5))

            snapshots.append(OrderbookSnapshot(
                timestamp=f"T-{limit - i}",
                bid_ask_spread=random.uniform(0.01, 0.15),
                depth_1pct=random.uniform(30000, 600000),
                depth_5pct=random.uniform(150000, 2500000),
                bid_depth_ratio=random.uniform(0.3, 0.7),
                large_order_count=random.randint(0, int(5 + spoof_base)),
                cancel_rate_5m=min(1.0, max(0, cancel_base + random.gauss(0, 0.05))),
                spoof_pattern_count=max(0, int(spoof_base + random.gauss(0, 1))),
                liquidity_void_depth=random.uniform(0, 4.0),
            ))
        return snapshots
