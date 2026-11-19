"""Tests for CryptoService."""
import os
from unittest.mock import patch

import pytest
from cryptography.fernet import Fernet

from app.services.crypto_service import CryptoService


class TestCryptoService:
    def test_encrypt_fails_closed_without_key(self):
        """Without a key, encrypting must fail instead of writing plaintext."""
        svc = CryptoService(key="")
        assert svc.is_encrypted is False
        with pytest.raises(RuntimeError, match="Encryption is not configured"):
            svc.encrypt("hello")
        # Legacy plaintext still decrypts for migration purposes.
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
