"""One-shot healing for provider credentials written before tenant keys."""
from __future__ import annotations

import logging

from app.database import SessionLocal
from app.services.providers.config_service import ProviderConfigService

logger = logging.getLogger(__name__)


def reencrypt_legacy_provider_credentials() -> int:
    db = SessionLocal()
    try:
        migrated = ProviderConfigService().reencrypt_legacy(db)
        db.commit()
        if migrated:
            logger.info("Re-encrypted %d provider credential rows with tenant keys", migrated)
        return migrated
    except Exception:
        db.rollback()
        logger.exception("provider credential key migration failed; keeping legacy ciphertext")
        return 0
    finally:
        db.close()
