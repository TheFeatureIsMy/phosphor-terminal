"""Market data provider registrations. All stubs (sub-project 4)."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

for _name in ("kline", "orderbook", "funding", "oi"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.MARKET_DATA
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title()}Provider"
    registry.register(_Stub)
