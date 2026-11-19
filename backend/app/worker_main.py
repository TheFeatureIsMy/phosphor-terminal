"""Worker-only process: runs background loops without serving HTTP."""
from __future__ import annotations

import asyncio
import logging
import signal

from app.config import settings
from app.logging import setup_logging
from app.runtime_loops import BackgroundLoops


async def _run() -> None:
    setup_logging(level=settings.log_level, fmt=settings.log_format)
    logger = logging.getLogger("app.worker")
    problems = settings.security_problems()
    if problems and settings.is_production:
        raise RuntimeError("Unsafe security configuration: " + "; ".join(problems))

    from app.services.system_trust import ensure_system_trust

    ensure_system_trust()
    # Importing the API module registers every ORM model via its routers.
    import app.main  # noqa: F401
    # Register every ORM model before create_all so a worker started without
    # migrations still creates the full schema.
    import app.models.user  # noqa: F401
    import app.models.tenant  # noqa: F401
    import app.models.strategy  # noqa: F401
    import app.models.agent_signal  # noqa: F401
    import app.models.ai  # noqa: F401
    import app.models.research  # noqa: F401
    import app.models.research_v2  # noqa: F401
    import app.models.dryrun  # noqa: F401
    import app.models.provider_config  # noqa: F401
    import app.domain.shadow_strategy  # noqa: F401
    import app.domain.archive  # noqa: F401
    import app.domain.feature  # noqa: F401
    import app.domain.trade_intent  # noqa: F401
    import app.domain.execution  # noqa: F401
    import app.domain.order  # noqa: F401
    import app.domain.reconciliation  # noqa: F401
    import app.domain.risk  # noqa: F401
    import app.domain.provider  # noqa: F401
    import app.domain.growth  # noqa: F401
    import app.domain.manipulation  # noqa: F401
    import app.domain.inference  # noqa: F401
    import app.domain.mcp  # noqa: F401

    from app.database import init_db

    init_db()
    from app.services.account_risk_firewall import AccountRiskFirewall

    AccountRiskFirewall.load_persisted_block()
    from app.services.providers.categories import register_all

    register_all()
    from app.services.providers.key_migration import reencrypt_legacy_provider_credentials

    reencrypt_legacy_provider_credentials()
    loops = BackgroundLoops()
    await loops.start()
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop.set)
    logger.info("worker loops started")
    try:
        await stop.wait()
    finally:
        await loops.stop()
        logger.info("worker loops stopped")


def main() -> None:
    asyncio.run(_run())


if __name__ == "__main__":
    main()
