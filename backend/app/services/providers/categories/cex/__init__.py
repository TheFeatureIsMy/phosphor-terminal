"""CEX provider registrations."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

from app.services.providers.categories.cex.binance import BinanceProvider
from app.services.providers.categories.cex.freqtrade import FreqtradeProvider
from app.services.providers.categories.cex.okx import OKXProvider
from app.services.providers.categories.cex.bybit import BybitProvider
from app.services.providers.categories.cex.bitget import BitgetProvider


for _cls in (
    BinanceProvider, FreqtradeProvider,
    OKXProvider, BybitProvider, BitgetProvider,
):
    registry.register(_cls)
