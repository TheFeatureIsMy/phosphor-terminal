"""On-chain provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.onchain.glassnode import GlassnodeProvider
from app.services.providers.categories.onchain.cryptoquant import CryptoQuantProvider
from app.services.providers.categories.onchain.whale_alert import WhaleAlertProvider


for _cls in (GlassnodeProvider, CryptoQuantProvider, WhaleAlertProvider):
    registry.register(_cls)
