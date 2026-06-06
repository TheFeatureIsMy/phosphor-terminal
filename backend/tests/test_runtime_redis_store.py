import pytest
from app.services.runtime_redis_store import RuntimeRedisStore

@pytest.fixture
def store():
    return RuntimeRedisStore(redis_url=None)

@pytest.mark.asyncio
async def test_ping_fallback(store):
    assert await store.ping() is True

@pytest.mark.asyncio
async def test_write_read_snapshot(store):
    snap = {"snapshot_id": "s1", "decision": "allow_trade"}
    await store.write_snapshot("strat1", "BTC/USDT", "5m", snap, ttl=60)
    result = await store.read_snapshot("strat1", "BTC/USDT", "5m")
    assert result["snapshot_id"] == "s1"

@pytest.mark.asyncio
async def test_read_missing_snapshot(store):
    result = await store.read_snapshot("none", "ETH/USDT", "1h")
    assert result is None

@pytest.mark.asyncio
async def test_snapshot_key_format(store):
    await store.write_snapshot("strat1", "BTC/USDT", "5m", {"id": "1"}, ttl=60)
    key = store._snapshot_key("strat1", "BTC/USDT", "5m")
    assert key == "pd:runtime:decision:strat1:BTC/USDT:5m"

@pytest.mark.asyncio
async def test_write_read_account_risk_state(store):
    state = {"allowed": True, "daily_pnl": -0.01}
    await store.write_account_risk_state("acc1", state, ttl=60)
    result = await store.read_account_risk_state("acc1")
    assert result["allowed"] is True

@pytest.mark.asyncio
async def test_write_read_ai_cache(store):
    cache = {"ai_risk_score": 0.42, "trade_permission": "allow"}
    await store.write_ai_cache("BTC/USDT", cache, ttl=900)
    result = await store.read_ai_cache("BTC/USDT")
    assert result["ai_risk_score"] == 0.42
