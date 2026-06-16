"""CEX provider registrations."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

from app.services.providers.categories.cex.binance import BinanceProvider
from app.services.providers.categories.cex.freqtrade import FreqtradeProvider


for _name in ("okx", "bybit", "bitget"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.CEX
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title()}Provider"
    registry.register(_Stub)

for _cls in (BinanceProvider, FreqtradeProvider):
    registry.register(_cls)
