"""Thin wrapper over CryptoService for provider credentials."""
from __future__ import annotations

import json

from app.services.crypto_service import CryptoService


class ProviderSecretCodec:
    def __init__(self, crypto: CryptoService | None = None) -> None:
        self._crypto = crypto or CryptoService()

    def encrypt_dict(self, credentials: dict | None) -> str | None:
        if credentials is None:
            return None
        if not isinstance(credentials, dict):
            raise TypeError("credentials must be a dict or None")
        payload = json.dumps(credentials, sort_keys=True, ensure_ascii=False)
        return self._crypto.encrypt(payload)

    def decrypt_dict(self, ciphertext: str | None) -> dict | None:
        if ciphertext is None:
            return None
        plaintext = self._crypto.decrypt(ciphertext)
        try:
            return json.loads(plaintext)
        except (json.JSONDecodeError, TypeError):
            return None

    @staticmethod
    def field_names(credentials: dict | None) -> list[str]:
        if not credentials or not isinstance(credentials, dict):
            return []
        return sorted(credentials.keys())
