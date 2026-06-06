from __future__ import annotations

import json
import logging
import os
from typing import Any

logger = logging.getLogger(__name__)


class RedisSnapshotClient:
    def __init__(self):
        self._redis = None
        self._available = False
        redis_url = os.environ.get("PULSEDESK_REDIS_URL")
        if redis_url:
            try:
                import redis
                self._redis = redis.Redis.from_url(redis_url, decode_responses=True)
                self._redis.ping()
                self._available = True
                logger.info("redis snapshot client connected: %s", redis_url)
            except Exception:
                logger.warning("redis unavailable, snapshot mode disabled")
                self._redis = None

    @property
    def available(self) -> bool:
        return self._available

    def read_snapshot(self, strategy_id: str, symbol: str, timeframe: str) -> dict[str, Any] | None:
        if not self._redis:
            return None
        key = f"pd:runtime:decision:{strategy_id}:{symbol}:{timeframe}"
        try:
            raw = self._redis.get(key)
            if raw:
                return json.loads(raw)
            return None
        except Exception:
            logger.warning("redis read failed for %s", key)
            return None

    def ping(self) -> bool:
        if not self._redis:
            return False
        try:
            return self._redis.ping()
        except Exception:
            return False
