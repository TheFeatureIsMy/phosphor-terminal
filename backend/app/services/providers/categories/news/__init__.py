"""News provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.news.cryptocompare_news import CryptoCompareNewsProvider
from app.services.providers.categories.news.cryptopanic import CryptoPanicProvider


for _cls in (CryptoCompareNewsProvider, CryptoPanicProvider):
    registry.register(_cls)
