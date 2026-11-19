"""Thin wrapper over CryptoService for provider credentials."""
from __future__ import annotations

import json

from app.services.crypto_service import CryptoService


class ProviderSecretCodec:
    def __init__(self, crypto: CryptoService | None = None) -> None:
        self._crypto = crypto or CryptoService()

    def encrypt_dict(self, credentials: dict | None, tenant_id: int | None = None) -> str | None:
        if credentials is None:
            return None
        if not isinstance(credentials, dict):
            raise TypeError("credentials must be a dict or None")
        payload = json.dumps(credentials, sort_keys=True, ensure_ascii=False)
        return self._crypto.encrypt(payload, tenant_id=tenant_id)

    def decrypt_dict(self, ciphertext: str | None, tenant_id: int | None = None) -> dict | None:
        parsed, _source = self.decrypt_dict_with_source(ciphertext, tenant_id=tenant_id)
        return parsed

    def decrypt_dict_with_source(
        self, ciphertext: str | None, tenant_id: int | None = None,
    ) -> tuple[dict | None, str | None]:
        """Return (credentials, key_source).

        key_source is "tenant", "master" (legacy row written before per-tenant
        keys), or None when nothing decrypts.
        """
        if ciphertext is None:
            return None, None
        for source, key_tenant in (("tenant", tenant_id), ("master", None)):
            if source == "master" and tenant_id is None:
                continue
            plaintext = self._crypto.decrypt(ciphertext, tenant_id=key_tenant)
            try:
                return json.loads(plaintext), source
            except (json.JSONDecodeError, TypeError):
                continue
        return None, None

    @staticmethod
    def field_names(credentials: dict | None) -> list[str]:
        if not credentials or not isinstance(credentials, dict):
            return []
        return sorted(credentials.keys())
