"""Notification provider registrations."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

from app.services.providers.categories.notification.telegram import TelegramProvider

for _name in ("discord", "email", "webhook"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.NOTIFICATION
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title()}Provider"
    registry.register(_Stub)

registry.register(TelegramProvider)
