"""Volatility Lock Service — 波动率锁定"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

from app.services.runtime_redis_store import RuntimeRedisStore

logger = logging.getLogger(__name__)


@dataclass
class VolatilityLockState:
    symbol: str
    timeframe: str = "5m"
    locked: bool = False
    lock_type: str | None = None
    trigger_value: float = 0
    threshold_value: float = 0
    reason_codes: list[str] = field(default_factory=list)


class VolatilityLockService:
    def __init__(self, redis_store: RuntimeRedisStore | None = None):
        self._store = redis_store

    async def list_locks(self, symbol: str | None = None) -> list[VolatilityLockState]:
        """List all active volatility locks, optionally filtered by symbol."""
        # In production, read from database and cache in Redis
        locks: list[VolatilityLockState] = []
        if self._store and symbol:
            cached = await self._store.read_volatility_lock(symbol)
            if cached:
                return [VolatilityLockState(**cached)]
        return locks

    async def check_and_lock(self, symbol: str, current_atr: float, threshold_atr: float) -> VolatilityLockState:
        """Check if volatility exceeds threshold and create lock if needed."""
        locked = current_atr > threshold_atr
        state = VolatilityLockState(
            symbol=symbol,
            locked=locked,
            lock_type="atr_spike" if locked else None,
            trigger_value=current_atr,
            threshold_value=threshold_atr,
            reason_codes=["atr_exceeds_threshold"] if locked else [],
        )
        if locked and self._store:
            await self._store.write_volatility_lock(symbol, {
                "symbol": state.symbol, "timeframe": state.timeframe,
                "locked": state.locked, "lock_type": state.lock_type,
                "trigger_value": state.trigger_value, "threshold_value": state.threshold_value,
                "reason_codes": state.reason_codes,
            }, ttl=10)
        return state

    async def release(self, symbol: str) -> None:
        """Release volatility lock for a symbol."""
        if self._store:
            await self._store.write_volatility_lock(symbol, {
                "symbol": symbol, "locked": False, "reason_codes": [],
            }, ttl=10)
