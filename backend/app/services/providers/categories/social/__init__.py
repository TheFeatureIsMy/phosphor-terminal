"""Social provider registrations."""
from app.services.providers.registry import registry

from app.services.providers.categories.social.cryptocompare_social import CryptoCompareSocialProvider
from app.services.providers.categories.social.lunarcrush import LunarCrushProvider
from app.services.providers.categories.social.x import XProvider


for _cls in (CryptoCompareSocialProvider, LunarCrushProvider, XProvider):
    registry.register(_cls)
