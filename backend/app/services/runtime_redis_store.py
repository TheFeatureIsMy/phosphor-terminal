from __future__ import annotations

import json
import logging
import time
from typing import Any

logger = logging.getLogger(__name__)


class RuntimeRedisStore:
    def __init__(self, redis_url: str | None = None):
        self._redis = None
        self._fallback: dict[str, tuple[str, float]] = {}

        if redis_url:
            try:
                import redis.asyncio as aioredis
                self._redis = aioredis.from_url(redis_url, decode_responses=True)
            except Exception:
                logger.warning("redis connection failed, using in-memory fallback")

    @staticmethod
    def _snapshot_key(strategy_id: str, symbol: str, timeframe: str) -> str:
        return f"pd:runtime:decision:{strategy_id}:{symbol}:{timeframe}"

    @staticmethod
    def _account_risk_key(account_id: str) -> str:
        return f"pd:runtime:account:{account_id}:risk_state"

    @staticmethod
    def _ai_cache_key(symbol: str) -> str:
        return f"pd:runtime:{symbol}:ai_risk_cache"

    async def ping(self) -> bool:
        if self._redis:
            try:
                return await self._redis.ping()
            except Exception:
                return False
        return True

    async def _set(self, key: str, value: dict, ttl: int) -> None:
        payload = json.dumps(value)
        if self._redis:
            try:
                await self._redis.set(key, payload, ex=ttl)
                return
            except Exception:
                logger.warning("redis write failed for %s, using fallback", key)
        self._fallback[key] = (payload, time.time() + ttl)

    async def _get(self, key: str) -> dict | None:
        if self._redis:
            try:
                raw = await self._redis.get(key)
                if raw:
                    return json.loads(raw)
                return None
            except Exception:
                logger.warning("redis read failed for %s, using fallback", key)

        entry = self._fallback.get(key)
        if entry:
            payload, expires_at = entry
            if time.time() < expires_at:
                return json.loads(payload)
            del self._fallback[key]
        return None

    async def write_snapshot(self, strategy_id: str, symbol: str, timeframe: str,
                             snapshot: dict, ttl: int = 300) -> None:
        key = self._snapshot_key(strategy_id, symbol, timeframe)
        await self._set(key, snapshot, ttl)

    async def read_snapshot(self, strategy_id: str, symbol: str, timeframe: str) -> dict | None:
        key = self._snapshot_key(strategy_id, symbol, timeframe)
        return await self._get(key)

    async def write_account_risk_state(self, account_id: str, state: dict, ttl: int = 60) -> None:
        key = self._account_risk_key(account_id)
        await self._set(key, state, ttl)

    async def read_account_risk_state(self, account_id: str) -> dict | None:
        key = self._account_risk_key(account_id)
        return await self._get(key)

    async def write_ai_cache(self, symbol: str, cache: dict, ttl: int = 900) -> None:
        key = self._ai_cache_key(symbol)
        await self._set(key, cache, ttl)

    async def read_ai_cache(self, symbol: str) -> dict | None:
        key = self._ai_cache_key(symbol)
        return await self._get(key)

    # ── BFF Keys ──

    @staticmethod
    def _global_status_key() -> str:
        return "pulsedesk:global:status"

    @staticmethod
    def _live_readiness_key(account_id: str) -> str:
        return f"pulsedesk:live_readiness:{account_id}"

    @staticmethod
    def _risk_guards_key(account_id: str) -> str:
        return f"pulsedesk:risk:guards:{account_id}"

    @staticmethod
    def _structure_matrix_key(symbol: str) -> str:
        return f"pulsedesk:structure:matrix:{symbol}"

    @staticmethod
    def _shadow_window_key(symbol: str, timeframe: str) -> str:
        return f"pulsedesk:structure:shadow:{symbol}:{timeframe}"

    @staticmethod
    def _stop_protection_key(position_id: str) -> str:
        return f"pulsedesk:stop:protection:{position_id}"

    @staticmethod
    def _volatility_lock_key(symbol: str) -> str:
        return f"pulsedesk:volatility:lock:{symbol}"

    @staticmethod
    def _execution_center_key() -> str:
        return "pulsedesk:execution:center"

    async def write_global_status(self, status: dict, ttl: int = 10) -> None:
        await self._set(self._global_status_key(), status, ttl)

    async def read_global_status(self) -> dict | None:
        return await self._get(self._global_status_key())

    async def write_live_readiness(self, account_id: str, data: dict, ttl: int = 30) -> None:
        await self._set(self._live_readiness_key(account_id), data, ttl)

    async def read_live_readiness(self, account_id: str) -> dict | None:
        return await self._get(self._live_readiness_key(account_id))

    async def write_structure_matrix(self, symbol: str, data: dict, ttl: int = 5) -> None:
        await self._set(self._structure_matrix_key(symbol), data, ttl)

    async def read_structure_matrix(self, symbol: str) -> dict | None:
        return await self._get(self._structure_matrix_key(symbol))

    async def write_stop_protection(self, position_id: str, data: dict, ttl: int = 5) -> None:
        await self._set(self._stop_protection_key(position_id), data, ttl)

    async def read_stop_protection(self, position_id: str) -> dict | None:
        return await self._get(self._stop_protection_key(position_id))

    async def write_volatility_lock(self, symbol: str, data: dict, ttl: int = 10) -> None:
        await self._set(self._volatility_lock_key(symbol), data, ttl)

    async def read_volatility_lock(self, symbol: str) -> dict | None:
        return await self._get(self._volatility_lock_key(symbol))

    async def write_execution_center(self, data: dict, ttl: int = 10) -> None:
        await self._set(self._execution_center_key(), data, ttl)

    async def read_execution_center(self) -> dict | None:
        return await self._get(self._execution_center_key())

    # ── MTF Guard Keys ──

    @staticmethod
    def _mtf_guard_key(strategy_id: str, symbol: str, fast_tf: str, slow_tf: str) -> str:
        return f"mtf_guard:{strategy_id}:{symbol}:{fast_tf}:{slow_tf}"

    @staticmethod
    def _mtf_guard_state_key(strategy_id: str, symbol: str) -> str:
        return f"mtf_guard_state:{strategy_id}:{symbol}"

    async def write_mtf_guard_state(
        self,
        strategy_id: str,
        symbol: str,
        fast_tf: str,
        slow_tf: str,
        state_data: dict,
        ttl: int = 300,
    ) -> None:
        """Write MTF guard state for a specific timeframe pair and an aggregate key."""
        pair_key = self._mtf_guard_key(strategy_id, symbol, fast_tf, slow_tf)
        await self._set(pair_key, state_data, ttl)

        # Also write to the aggregate state key (latest guard state for this symbol)
        agg_key = self._mtf_guard_state_key(strategy_id, symbol)
        aggregate = {
            "fast_tf": fast_tf,
            "slow_tf": slow_tf,
            **state_data,
        }
        await self._set(agg_key, aggregate, ttl)

    async def read_mtf_guard_state(self, strategy_id: str, symbol: str) -> dict | None:
        """Read the aggregate MTF guard state for a symbol."""
        key = self._mtf_guard_state_key(strategy_id, symbol)
        return await self._get(key)

    async def read_mtf_guard_pair(
        self,
        strategy_id: str,
        symbol: str,
        fast_tf: str,
        slow_tf: str,
    ) -> dict | None:
        """Read MTF guard state for a specific timeframe pair."""
        key = self._mtf_guard_key(strategy_id, symbol, fast_tf, slow_tf)
        return await self._get(key)
