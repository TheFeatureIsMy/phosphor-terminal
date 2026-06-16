"""On-chain provider registrations. All stubs (sub-project 5)."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

for _name in ("glassnode", "cryptoquant", "whale_alert"):
    class _Stub(ProviderStubBase):
        category = ProviderCategory.ONCHAIN
        provider_name = _name
        is_multi_instance = False
    _Stub.__name__ = f"{_name.title().replace('_', '')}Provider"
    registry.register(_Stub)
