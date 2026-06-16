"""Social provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.social.cryptocompare_social import CryptoCompareSocialProvider
from app.services.providers.categories.social.lunarcrush import LunarCrushProvider


for _cls in (CryptoCompareSocialProvider, LunarCrushProvider):
    registry.register(_cls)
