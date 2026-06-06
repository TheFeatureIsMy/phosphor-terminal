"""Redis cache with graceful in-memory fallback."""
from __future__ import annotations

import json
import logging
import time
from typing import Any, Optional

logger = logging.getLogger(__name__)

# Default TTLs per domain (seconds)
_TTL_SIGNAL = 3600  # overridden by signal's expires_at
_TTL_MARKET_1M = 90
_TTL_MARKET_1H = 5400
_TTL_FEATURE_MULTIPLIER = 1.5  # 1.5x the timeframe duration
_TTL_MANIPULATION = 900
_TTL_RISK = 300
_TTL_AGENT = 600
_TTL_STRATEGY = 86400


class RedisCache:
    """Redis-backed cache. Falls back to in-memory dict if Redis unavailable."""

    def __init__(self, redis_url: str | None = None):
        self._redis = None
        self._fallback: dict[str, tuple[Any, float | None]] = {}
        if redis_url:
            try:
                import redis as redis_lib

                self._redis = redis_lib.Redis.from_url(
                    redis_url, decode_responses=True
                )
                self._redis.ping()
                logger.info("Redis connected: %s", redis_url)
            except Exception as exc:
                logger.warning(
                    "Redis unavailable (%s), using in-memory fallback", exc
                )
                self._redis = None

    @property
    def is_redis(self) -> bool:
        """Return True if backed by Redis, False if using fallback."""
        return self._redis is not None

    # ------------------------------------------------------------------
    # Core operations
    # ------------------------------------------------------------------

    def get(self, key: str) -> Any | None:
        """Get a value by key. Returns None if missing or expired."""
        if self._redis:
            raw = self._redis.get(key)
            if raw is None:
                return None
            try:
                return json.loads(raw)
            except (json.JSONDecodeError, TypeError):
                return raw
        else:
            if key not in self._fallback:
                return None
            value, expiry = self._fallback[key]
            if expiry is not None and time.time() >= expiry:
                del self._fallback[key]
                return None
            return value

    def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        """Set a value with optional TTL in seconds."""
        if self._redis:
            serialized = json.dumps(value) if not isinstance(value, str) else value
            if ttl:
                self._redis.setex(key, ttl, serialized)
            else:
                self._redis.set(key, serialized)
        else:
            expiry = (time.time() + ttl) if ttl else None
            self._fallback[key] = (value, expiry)

    def delete(self, key: str) -> None:
        """Delete a key."""
        if self._redis:
            self._redis.delete(key)
        else:
            self._fallback.pop(key, None)

    def exists(self, key: str) -> bool:
        """Check if a key exists and is not expired."""
        if self._redis:
            return bool(self._redis.exists(key))
        else:
            if key not in self._fallback:
                return False
            _, expiry = self._fallback[key]
            if expiry is not None and time.time() >= expiry:
                del self._fallback[key]
                return False
            return True

    # ------------------------------------------------------------------
    # Key helpers — standardized key formats per domain
    # ------------------------------------------------------------------

    @staticmethod
    def signal_key(symbol: str) -> str:
        """Key for signal cache entry."""
        return f"signal:{symbol.upper()}"

    @staticmethod
    def market_key(symbol: str, timeframe: str) -> str:
        """Key for market data cache entry."""
        return f"market:{symbol.upper()}:{timeframe}"

    @staticmethod
    def feature_key(symbol: str, timeframe: str) -> str:
        """Key for computed feature cache entry."""
        return f"feature:{symbol.upper()}:{timeframe}"

    @staticmethod
    def risk_key(symbol: str) -> str:
        """Key for risk assessment cache entry."""
        return f"risk:{symbol.upper()}"

    @staticmethod
    def agent_key(agent_id: str) -> str:
        """Key for agent state cache entry."""
        return f"agent:{agent_id}"

    @staticmethod
    def strategy_key(strategy_id: str) -> str:
        """Key for strategy config cache entry."""
        return f"strategy:{strategy_id}"

    # ------------------------------------------------------------------
    # TTL helpers — returns recommended TTL for each domain
    # ------------------------------------------------------------------

    @staticmethod
    def signal_ttl(expires_in_seconds: int) -> int:
        """Signal TTL is driven by the signal's own expiration."""
        return max(expires_in_seconds, 60)

    @staticmethod
    def market_ttl(timeframe: str) -> int:
        """Market data TTL based on timeframe."""
        mapping = {
            "1m": _TTL_MARKET_1M,
            "5m": 450,
            "15m": 1350,
            "1h": _TTL_MARKET_1H,
            "4h": 21600,
            "1d": 86400,
        }
        return mapping.get(timeframe, _TTL_MARKET_1H)

    @staticmethod
    def feature_ttl(timeframe: str) -> int:
        """Feature TTL is 1.5x the timeframe duration."""
        duration_map = {
            "1m": 60,
            "5m": 300,
            "15m": 900,
            "1h": 3600,
            "4h": 14400,
            "1d": 86400,
        }
        base = duration_map.get(timeframe, 3600)
        return int(base * _TTL_FEATURE_MULTIPLIER)

    @staticmethod
    def manipulation_ttl() -> int:
        """Manipulation score TTL."""
        return _TTL_MANIPULATION

    @staticmethod
    def risk_ttl() -> int:
        """Risk assessment TTL."""
        return _TTL_RISK

    @staticmethod
    def agent_ttl() -> int:
        """Agent state TTL."""
        return _TTL_AGENT

    @staticmethod
    def strategy_ttl() -> int:
        """Strategy config TTL."""
        return _TTL_STRATEGY

    # ------------------------------------------------------------------
    # Convenience set methods with domain-specific TTL
    # ------------------------------------------------------------------

    def set_signal(self, symbol: str, value: Any, expires_in_seconds: int) -> None:
        """Cache a signal with its natural expiration TTL."""
        self.set(
            self.signal_key(symbol), value, self.signal_ttl(expires_in_seconds)
        )

    def set_market(self, symbol: str, timeframe: str, value: Any) -> None:
        """Cache market data with timeframe-appropriate TTL."""
        self.set(
            self.market_key(symbol, timeframe), value, self.market_ttl(timeframe)
        )

    def set_feature(self, symbol: str, timeframe: str, value: Any) -> None:
        """Cache computed features with 1.5x timeframe TTL."""
        self.set(
            self.feature_key(symbol, timeframe), value, self.feature_ttl(timeframe)
        )

    def set_risk(self, symbol: str, value: Any) -> None:
        """Cache risk assessment."""
        self.set(self.risk_key(symbol), value, self.risk_ttl())

    def set_agent(self, agent_id: str, value: Any) -> None:
        """Cache agent state."""
        self.set(self.agent_key(agent_id), value, self.agent_ttl())

    def set_strategy(self, strategy_id: str, value: Any) -> None:
        """Cache strategy config."""
        self.set(self.strategy_key(strategy_id), value, self.strategy_ttl())
