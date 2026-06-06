"""Stop Protection Service — 止损保护"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

from app.services.runtime_redis_store import RuntimeRedisStore

logger = logging.getLogger(__name__)


@dataclass
class StopLevels:
    raw_structure_stop: float | None = None
    last_known_good_stop: float | None = None
    secure_runtime_stop: float | None = None
    exchange_protective_stop: float | None = None
    volatility_locked: bool = False


@dataclass
class PositionStopState:
    position_id: str
    symbol: str
    side: str
    entry_price: float
    current_price: float
    stops: StopLevels = field(default_factory=StopLevels)
    stop_update_allowed: bool = True
    reason_codes: list[str] = field(default_factory=list)


@dataclass
class StopProtectionResult:
    state: str = "healthy"
    reason_codes: list[str] = field(default_factory=list)
    positions: list[PositionStopState] = field(default_factory=list)
    volatility_locks: list[dict] = field(default_factory=list)


class StopProtectionService:
    def __init__(self, redis_store: RuntimeRedisStore | None = None):
        self._store = redis_store

    async def get_all(self) -> StopProtectionResult:
        """Get stop protection state for all active positions."""
        # In production this would query real positions from Freqtrade/Exchange
        # and compute structure stops via StructureEngine.stop_calculator
        positions = self._mock_positions()
        overall_state = "healthy"
        overall_reasons: list[str] = []

        for pos in positions:
            if pos.stops.volatility_locked:
                overall_state = "warning"
                overall_reasons.append(f"{pos.symbol}_volatility_locked")
            if not pos.stop_update_allowed:
                overall_state = "warning"
                overall_reasons.append(f"{pos.symbol}_stop_update_blocked")

            if self._store:
                await self._store.write_stop_protection(pos.position_id, {
                    "symbol": pos.symbol, "side": pos.side,
                    "entry_price": pos.entry_price, "current_price": pos.current_price,
                    "raw_structure_stop": pos.stops.raw_structure_stop,
                    "last_known_good_stop": pos.stops.last_known_good_stop,
                    "secure_runtime_stop": pos.stops.secure_runtime_stop,
                    "exchange_protective_stop": pos.stops.exchange_protective_stop,
                    "volatility_locked": pos.stops.volatility_locked,
                    "stop_update_allowed": pos.stop_update_allowed,
                    "reason_codes": pos.reason_codes,
                }, ttl=5)

        return StopProtectionResult(
            state=overall_state, reason_codes=overall_reasons,
            positions=positions, volatility_locks=[],
        )

    async def refresh_position(self, position_id: str) -> PositionStopState | None:
        """Refresh stop levels for a single position."""
        result = await self.get_all()
        for pos in result.positions:
            if pos.position_id == position_id:
                return pos
        return None

    def _mock_positions(self) -> list[PositionStopState]:
        return [
            PositionStopState(
                position_id="pos-001", symbol="BTC/USDT", side="long",
                entry_price=62100, current_price=62450,
                stops=StopLevels(
                    raw_structure_stop=61200, last_known_good_stop=61350,
                    secure_runtime_stop=61350, exchange_protective_stop=61000,
                ),
                reason_codes=["structure_stop_valid"],
            ),
            PositionStopState(
                position_id="pos-002", symbol="ETH/USDT", side="long",
                entry_price=3380, current_price=3410,
                stops=StopLevels(
                    raw_structure_stop=3300, last_known_good_stop=3320,
                    secure_runtime_stop=3320, exchange_protective_stop=3280,
                ),
                reason_codes=["structure_stop_valid"],
            ),
        ]
