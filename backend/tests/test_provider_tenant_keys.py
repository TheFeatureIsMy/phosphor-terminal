"""Provider credentials use per-tenant derived keys."""
from cryptography.fernet import Fernet

from app.services.crypto_service import CryptoService
from app.services.providers.crypto import ProviderSecretCodec


def test_tenant_key_roundtrip_and_isolation():
    key = Fernet.generate_key().decode()
    crypto = CryptoService(key=key)
    codec = ProviderSecretCodec(crypto)

    ciphertext = codec.encrypt_dict({"api_key": "tenant-one-secret"}, tenant_id=1)
    assert ciphertext
    assert codec.decrypt_dict(ciphertext, tenant_id=1) == {
        "api_key": "tenant-one-secret"
    }
    # A different tenant's derived key must not decrypt it.
    assert codec.decrypt_dict(ciphertext, tenant_id=2) is None


def test_global_key_still_decrypts_legacy_rows():
    key = Fernet.generate_key().decode()
    crypto = CryptoService(key=key)
    codec = ProviderSecretCodec(crypto)

    legacy = codec.encrypt_dict({"api_key": "global"}, tenant_id=None)
    assert codec.decrypt_dict(legacy, tenant_id=None) == {"api_key": "global"}


def test_legacy_ciphertext_falls_back_and_heals(session):
    from app.models.provider_config import ProviderConfig
    from app.models.tenant import Tenant
    from app.services.providers.config_service import ProviderConfigService

    session.add(Tenant(id=7, name="provider-7", slug="provider-7"))
    session.flush()
    key = Fernet.generate_key().decode()
    crypto = CryptoService(key=key)
    codec = ProviderSecretCodec(crypto)
    legacy_ct = codec.encrypt_dict({"api_key": "old"}, tenant_id=None)

    row = ProviderConfig(
        tenant_id=7, category="cex", provider_name="binance",
        config={}, credentials_ct=legacy_ct, credentials_fields=["api_key"],
        enabled=True, is_active=False, priority=0, status="unknown",
        credential_status="configured",
    )
    session.add(row)
    session.commit()

    service = ProviderConfigService(crypto=crypto)
    assert service.decrypt_credentials(row) == {"api_key": "old"}
    assert service.reencrypt_legacy(session) == 1
    session.commit()
    session.refresh(row)
    assert service.decrypt_credentials(row) == {"api_key": "old"}

    # After healing, the global key must no longer decrypt the row.
    assert codec.decrypt_dict(row.credentials_ct, tenant_id=None) is None


def test_plaintext_legacy_credentials_are_encrypted_on_heal(session):
    from app.models.provider_config import ProviderConfig
    from app.services.providers.config_service import ProviderConfigService

    from app.models.tenant import Tenant

    session.add(Tenant(id=8, name="provider-8", slug="provider-8"))
    session.flush()
    key = Fernet.generate_key().decode()
    crypto = CryptoService(key=key)
    row = ProviderConfig(
        tenant_id=8, category="cex", provider_name="okx",
        config={}, credentials_ct='{"api_key":"plain"}',
        credentials_fields=["api_key"], enabled=True, is_active=False,
        priority=0, status="unknown", credential_status="configured",
    )
    session.add(row)
    session.commit()

    service = ProviderConfigService(crypto=crypto)
    assert service.decrypt_credentials(row) == {"api_key": "plain"}
    assert service.reencrypt_legacy(session) == 1
    session.commit()
    session.refresh(row)
    assert not row.credentials_ct.lstrip().startswith("{")
    assert service.decrypt_credentials(row) == {"api_key": "plain"}


def test_llm_selects_only_current_tenant_provider(session):
    from app.models.provider_config import ProviderConfig
    from app.models.tenant import Tenant
    from app.services.llm_service import LLMService
    from app.services.providers.config_service import ProviderConfigService

    key = Fernet.generate_key().decode()
    crypto = CryptoService(key=key)
    codec = ProviderSecretCodec(crypto)
    t1 = Tenant(name="llm-a", slug="llm-a")
    t2 = Tenant(name="llm-b", slug="llm-b")
    session.add_all([t1, t2])
    session.flush()

    for tenant, name, secret in [(t1, "openai-a", "key-a"), (t2, "openai-b", "key-b")]:
        session.add(ProviderConfig(
            tenant_id=tenant.id, category="llm", provider_name="openai",
            instance_name=name, config={"model": "gpt-4o"},
            credentials_ct=codec.encrypt_dict({"api_key": secret}, tenant_id=tenant.id),
            credentials_fields=["api_key"], enabled=True, is_active=False,
            priority=0, status="active", credential_status="configured",
        ))
    session.commit()

    service = LLMService(
        config_service=ProviderConfigService(crypto=crypto), tenant_id=t1.id,
    )
    selected = service.select_provider(session)
    assert selected is not None
    assert selected.instance_name == "openai-a"
    assert service._config_service.decrypt_credentials(selected) == {"api_key": "key-a"}
