"""Provider adapter registration stub.

PR2 (adapters) will populate this with real imports that register each
adapter class on the global `registry`. For now this is a no-op so that
the scheduler can start without error.

See docs/superpowers/specs/2026-06-16-provider-adapter-foundation-design.md §4.
"""
from __future__ import annotations

import logging

logger = logging.getLogger(__name__)


def register_all() -> None:
    """Register all available provider adapters.

    Importing each adapter module triggers its module-level registration
    call on `app.services.providers.registry.registry`.
    """
    logger.debug("No provider adapters registered yet (stub categories.py)")
