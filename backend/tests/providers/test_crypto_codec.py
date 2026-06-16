"""Tests for ProviderSecretCodec."""
from __future__ import annotations

import json

import pytest


@pytest.fixture
def fernet_key(monkeypatch):
    from cryptography.fernet import Fernet
    key = Fernet.generate_key().decode()
    monkeypatch.setenv("PULSEDESK_ENCRYPTION_KEY", key)
    yield key


def test_codec_encrypts_credentials_dict(fernet_key):
    import importlib
    from app.services import crypto_service
    importlib.reload(crypto_service)
    from app.services.providers.crypto import ProviderSecretCodec
    from app.services.crypto_service import CryptoService

    crypto = CryptoService()
    codec = ProviderSecretCodec(crypto=crypto)

    creds = {"api_key": "sk-abc-123", "api_secret": "very-secret"}
    ciphertext = codec.encrypt_dict(creds)
    assert ciphertext != json.dumps(creds)
    assert "sk-abc-123" not in ciphertext

    decoded = codec.decrypt_dict(ciphertext)
    assert decoded == creds


def test_codec_extracts_field_names():
    from app.services.providers.crypto import ProviderSecretCodec
    from app.services.crypto_service import CryptoService

    codec = ProviderSecretCodec(crypto=CryptoService())
    creds = {"api_key": "x", "api_secret": "y", "passphrase": "z"}
    assert codec.field_names(creds) == ["api_key", "api_secret", "passphrase"]


def test_codec_handles_none_input():
    from app.services.providers.crypto import ProviderSecretCodec
    from app.services.crypto_service import CryptoService

    codec = ProviderSecretCodec(crypto=CryptoService())
    assert codec.encrypt_dict(None) is None
    assert codec.decrypt_dict(None) is None
    assert codec.field_names(None) == []
