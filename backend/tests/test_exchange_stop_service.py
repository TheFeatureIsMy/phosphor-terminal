import pytest
from app.services.exchange_stop_service import ExchangeStopService

@pytest.fixture
def service():
    return ExchangeStopService(dry_run=True)

@pytest.mark.asyncio
async def test_place_protective_stop_dry_run(service):
    result = await service.place_protective_stop("BTC/USDT", "sell", 0.1, 60000)
    assert result.success is True
    assert result.order_id is not None
    assert result.stop_price == 60000

@pytest.mark.asyncio
async def test_place_no_client(service):
    svc = ExchangeStopService(freqtrade_client=None, dry_run=False)
    result = await svc.place_protective_stop("BTC/USDT", "sell", 0.1, 60000)
    assert result.success is False
    assert result.error == "no_freqtrade_client"

@pytest.mark.asyncio
async def test_update_cancels_and_replaces(service):
    r1 = await service.place_protective_stop("BTC/USDT", "sell", 0.1, 60000)
    r2 = await service.update_protective_stop("BTC/USDT", r1.order_id, 61000, 0.1, "sell")
    assert r2.success is True
    assert r2.stop_price == 61000
