"""Fernet-based symmetric encryption for API keys.

Security contract (P0, 2026-11-15):
- ``encrypt`` fails closed when no key is configured. Credentials are never
  written as plaintext.
- ``decrypt`` still accepts legacy plaintext values so existing rows can be
  migrated, but logs a warning once.
"""
from __future__ import annotations

import base64
import logging
import os

from app.config import settings

logger = logging.getLogger(__name__)


class CryptoService:
    """Encrypts/decrypts sensitive data using Fernet."""

    def __init__(self, key: str | None = None) -> None:
        if key is None:
            key = os.environ.get("PULSEDESK_ENCRYPTION_KEY") or settings.pulsedesk_encryption_key
        key = (key or "").strip()
        self._fernet = None
        self._master_key: bytes | None = None
        self._tenant_fernets: dict[int, object] = {}
        if not key:
            logger.error(
                "PULSEDESK_ENCRYPTION_KEY is not set — credential writes will be rejected"
            )
            return
        try:
            from cryptography.fernet import Fernet

            self._fernet = Fernet(key.encode() if isinstance(key, str) else key)
            self._master_key = base64.urlsafe_b64decode(key)
            logger.info("CryptoService initialized with Fernet encryption")
        except Exception as exc:
            raise RuntimeError(
                "PULSEDESK_ENCRYPTION_KEY is invalid; refusing to start with broken encryption"
            ) from exc

    @property
    def is_encrypted(self) -> bool:
        """Return True if real encryption is active."""
        return self._fernet is not None

    def _fernet_for(self, tenant_id: int | None):
        if tenant_id is None or self._master_key is None:
            return self._fernet
        cached = self._tenant_fernets.get(tenant_id)
        if cached is not None:
            return cached
        from cryptography.fernet import Fernet
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.kdf.hkdf import HKDF

        derived = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=b"alphaloop-provider-credentials",
            info=f"tenant:{tenant_id}".encode(),
        ).derive(self._master_key)
        fernet = Fernet(base64.urlsafe_b64encode(derived))
        self._tenant_fernets[tenant_id] = fernet
        return fernet

    def encrypt(self, plaintext: str, tenant_id: int | None = None) -> str:
        """Encrypt a plaintext string. Raises when no key is configured."""
        fernet = self._fernet_for(tenant_id)
        if not fernet:
            raise RuntimeError(
                "Encryption is not configured: set PULSEDESK_ENCRYPTION_KEY before "
                "storing credentials"
            )
        return fernet.encrypt(plaintext.encode()).decode()

    def decrypt(self, ciphertext: str, tenant_id: int | None = None) -> str:
        """Decrypt a ciphertext string. Legacy plaintext passes through."""
        fernet = self._fernet_for(tenant_id)
        if not fernet:
            return ciphertext
        try:
            return fernet.decrypt(ciphertext.encode()).decode()
        except Exception:
            # May be a legacy plaintext value stored before encryption was enabled
            logger.warning(
                "Decryption failed, returning raw value (possible legacy plaintext)"
            )
            return ciphertext


# Module-level singleton
crypto_service = CryptoService()
