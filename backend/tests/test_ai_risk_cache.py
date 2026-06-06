import pytest
from app.services.ai_risk_cache import AIRiskCacheService
from app.services.runtime_redis_store import RuntimeRedisStore

@pytest.fixture
def store():
    return RuntimeRedisStore(redis_url=None)

@pytest.fixture
def cache_svc(store):
    return AIRiskCacheService(redis_store=store, llm_service=None)

@pytest.mark.asyncio
async def test_refresh_writes_to_redis(cache_svc, store):
    result = await cache_svc.refresh("BTC/USDT")
    assert "ai_risk_score" in result
    cached = await store.read_ai_cache("BTC/USDT")
    assert cached is not None
    assert cached["ai_risk_score"] == result["ai_risk_score"]

@pytest.mark.asyncio
async def test_refresh_aggregates_analyzers(cache_svc):
    result = await cache_svc.refresh("BTC/USDT")
    assert "analyzer_results" in result
    assert "news_risk" in result["analyzer_results"]
    assert "whale_risk" in result["analyzer_results"]
    assert "conflict_analysis" in result["analyzer_results"]

@pytest.mark.asyncio
async def test_get_cached_empty(cache_svc):
    result = await cache_svc.get_cached("ETH/USDT")
    assert result is None

@pytest.mark.asyncio
async def test_trade_permission_high_risk(store):
    svc = AIRiskCacheService(redis_store=store, llm_service=None)
    result = await svc.refresh("BTC/USDT")
    # Default analyzers return low risk, so permission should be "allow"
    assert result["trade_permission"] in ("allow", "reduce_size")
