import pytest
import time
from app.services.heartbeat_monitor import HeartbeatMonitor, HeartbeatStatus
from app.services.runtime_redis_store import RuntimeRedisStore

@pytest.fixture
def store():
    return RuntimeRedisStore(redis_url=None)

@pytest.fixture
def monitor(store):
    return HeartbeatMonitor(redis_store=store, stale_threshold_s=5)

@pytest.mark.asyncio
async def test_fresh_heartbeat_alive(monitor):
    await monitor.record_heartbeat("strat1")
    status = await monitor.check_alive("strat1")
    assert status.alive is True
    assert status.last_seen_at is not None
    assert status.stale_seconds < 2

@pytest.mark.asyncio
async def test_no_heartbeat_not_alive(monitor):
    status = await monitor.check_alive("nonexistent")
    assert status.alive is False
    assert status.last_seen_at is None

@pytest.mark.asyncio
async def test_stale_heartbeat(store):
    monitor = HeartbeatMonitor(redis_store=store, stale_threshold_s=0)
    await monitor.record_heartbeat("strat1")
    status = await monitor.check_alive("strat1")
    assert status.alive is False

@pytest.mark.asyncio
async def test_metadata_preserved(monitor):
    await monitor.record_heartbeat("strat1", metadata={"pair_count": 5})
    status = await monitor.check_alive("strat1")
    assert status.metadata == {"pair_count": 5}
