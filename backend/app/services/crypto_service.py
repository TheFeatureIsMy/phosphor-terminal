"""Fernet-based symmetric encryption for API keys."""
from __future__ import annotations

import os
import logging

logger = logging.getLogger(__name__)


class CryptoService:
    """Encrypts/decrypts sensitive data using Fernet.

    Falls back to passthrough when PULSEDESK_ENCRYPTION_KEY is not set (dev mode).
    """

    def __init__(self) -> None:
        key = os.environ.get("PULSEDESK_ENCRYPTION_KEY")
        self._fernet = None
        if key:
            try:
                from cryptography.fernet import Fernet

                # Key must be 32 url-safe base64-encoded bytes
                self._fernet = Fernet(key.encode() if isinstance(key, str) else key)
                logger.info("CryptoService initialized with Fernet encryption")
            except Exception as exc:
                logger.warning(
                    "Invalid encryption key (%s), falling back to passthrough", exc
                )
        else:
            logger.info(
                "PULSEDESK_ENCRYPTION_KEY not set — CryptoService running in passthrough mode"
            )

    @property
    def is_encrypted(self) -> bool:
        """Return True if real encryption is active."""
        return self._fernet is not None

    def encrypt(self, plaintext: str) -> str:
        """Encrypt a plaintext string. Returns ciphertext or passthrough in dev mode."""
        if not self._fernet:
            return plaintext
        return self._fernet.encrypt(plaintext.encode()).decode()

    def decrypt(self, ciphertext: str) -> str:
        """Decrypt a ciphertext string. Falls back to returning input on failure."""
        if not self._fernet:
            return ciphertext
        try:
            return self._fernet.decrypt(ciphertext.encode()).decode()
        except Exception:
            # May be a legacy plaintext value stored before encryption was enabled
            logger.debug("Decryption failed, returning raw value (possible legacy plaintext)")
            return ciphertext
