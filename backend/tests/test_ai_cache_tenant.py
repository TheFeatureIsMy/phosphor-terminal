"""AI risk cache keys must not collide across tenants."""
import pytest

from app.services.runtime_redis_store import RuntimeRedisStore


@pytest.mark.asyncio
async def test_ai_cache_is_namespaced_by_tenant():
    store = RuntimeRedisStore(redis_url=None)
    await store.write_ai_cache("BTC/USDT", {"score": 1}, tenant_id=1)

    assert (await store.read_ai_cache("BTC/USDT", tenant_id=1)) == {"score": 1}
    assert await store.read_ai_cache("BTC/USDT", tenant_id=2) is None
    # Global/legacy key is separate as well.
    assert await store.read_ai_cache("BTC/USDT") is None
