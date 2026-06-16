"""Market data provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.market_data.kline import KlineProvider
from app.services.providers.categories.market_data.orderbook import OrderbookProvider
from app.services.providers.categories.market_data.funding import FundingProvider
from app.services.providers.categories.market_data.oi import OIProvider


for _cls in (KlineProvider, OrderbookProvider, FundingProvider, OIProvider):
    registry.register(_cls)
