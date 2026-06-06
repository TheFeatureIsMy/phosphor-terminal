from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

from app.services.runtime_redis_store import RuntimeRedisStore

logger = logging.getLogger(__name__)


@dataclass
class HeartbeatStatus:
    alive: bool
    last_seen_at: Optional[datetime]
    stale_seconds: float
    metadata: dict | None = None


class HeartbeatMonitor:
    def __init__(self, redis_store: RuntimeRedisStore, stale_threshold_s: int = 30):
        self._store = redis_store
        self._stale_threshold = stale_threshold_s

    async def record_heartbeat(self, strategy_id: str, metadata: dict | None = None) -> None:
        key = f"pd:runtime:heartbeat:{strategy_id}"
        value = {
            "ts": time.time(),
            "strategy_id": strategy_id,
            "metadata": metadata or {},
        }
        await self._store._set(key, value, ttl=self._stale_threshold * 2)

    async def check_alive(self, strategy_id: str) -> HeartbeatStatus:
        key = f"pd:runtime:heartbeat:{strategy_id}"
        data = await self._store._get(key)

        if not data:
            return HeartbeatStatus(alive=False, last_seen_at=None, stale_seconds=float("inf"))

        ts = data.get("ts", 0)
        elapsed = time.time() - ts
        last_seen = datetime.fromtimestamp(ts, tz=timezone.utc)

        return HeartbeatStatus(
            alive=elapsed <= self._stale_threshold,
            last_seen_at=last_seen,
            stale_seconds=elapsed,
            metadata=data.get("metadata"),
        )
