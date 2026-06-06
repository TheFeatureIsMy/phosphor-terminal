"""Tests for CryptoService."""
import os
from unittest.mock import patch

from cryptography.fernet import Fernet

from app.services.crypto_service import CryptoService


class TestCryptoService:
    def test_passthrough_when_no_key(self):
        """Without encryption key, values pass through unchanged."""
        env = os.environ.copy()
        env.pop("PULSEDESK_ENCRYPTION_KEY", None)
        with patch.dict(os.environ, env, clear=True):
            svc = CryptoService()
            assert svc.encrypt("hello") == "hello"
            assert svc.decrypt("hello") == "hello"

    def test_encrypt_decrypt_roundtrip(self):
        """With valid key, encrypt then decrypt returns original."""
        key = Fernet.generate_key().decode()
        with patch.dict(os.environ, {"PULSEDESK_ENCRYPTION_KEY": key}):
            svc = CryptoService()
            plaintext = "sk-my-secret-api-key-12345"
            encrypted = svc.encrypt(plaintext)
            assert encrypted != plaintext  # Should be different
            decrypted = svc.decrypt(encrypted)
            assert decrypted == plaintext

    def test_decrypt_legacy_plaintext(self):
        """Decrypting a non-encrypted value returns it as-is (legacy support)."""
        key = Fernet.generate_key().decode()
        with patch.dict(os.environ, {"PULSEDESK_ENCRYPTION_KEY": key}):
            svc = CryptoService()
            # A plaintext value that's not valid Fernet
            legacy = "old-plaintext-key"
            assert svc.decrypt(legacy) == legacy
