import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware

from app.config import settings
from app.database import init_db
from app.logging import setup_logging
from app.middleware import ErrorHandlerMiddleware, RateLimitMiddleware, RequestLoggerMiddleware
from app.security import AuthMiddleware
from app.security.deps import require_platform_admin, require_superuser
from app.routers import (
    manipulation,
    growth,
    live_small,
    health, commands, ledger, strategies, strategies_v2, orders, dashboard, backtest, dryrun, risk, system, auth,
    search, notifications, attribution, sentiment, rag, markets,
    ai_research, agent_signals, ai_providers, factor_research, websocket,
    signals_v2, strategy_runs, inference, mcp,
    decision, emergency_v2,
)
from app.routers import shadow_strategy
from app.routers import invites, members, overview, execution_bff, reconciliation_bff, risk_bff, structure_bff
from app.routers import market_structure_bff, failure_clustering_bff
from app.routers import workflow
from app.routers import trading
from app.routers import trace
from app.routers import state_leases, canvas
from app.routers import agents as agents_router_module
from app.routers.admin.execution_profile import router as admin_execution_profile_router
from app.routers.admin.sessions import router as admin_sessions_router
from app.routers.admin.tenant_plan import router as admin_tenant_plan_router
from app.routers.admin.tenant_audit import router as admin_tenant_audit_router
from app.routers.admin.tenant_usage import router as admin_tenant_usage_router
from app.routers.admin.tenant_subscription import router as admin_tenant_subscription_router
from app.routers.admin.providers import router as admin_providers_router
from app.routers.admin.system_settings import router as admin_system_settings_router
from app.routers.admin import router as admin_router
from app.routers.providers_ws import router as providers_ws_router
from app.routers.strategy_workspace import router as strategy_workspace_router
from app.routers.manipulation_ws import router as manipulation_ws_router
from app.routers.trade_intents import router as trade_intents_router
from app.routers.alert_rules import router as alert_rules_router
from app.routers.canvas_ai import router as canvas_ai_router
from app.routers.billing import router as billing_router
from app.services.providers.realtime.ccxt_ticker_stream import run_binance_ticker_stream
from app.workers.worker_loop import CommandWorkerLoop
from app.workers.trade_sync_loop import TradeSyncLoop


@asynccontextmanager
async def lifespan(app: FastAPI):
    from app.services.system_trust import ensure_system_trust
    ensure_system_trust()
    setup_logging(level=settings.log_level, fmt=settings.log_format)
    logger = logging.getLogger("app.main")
    problems = settings.security_problems()
    if problems and settings.is_production:
        raise RuntimeError("Unsafe security configuration: " + "; ".join(problems))
    if problems and settings.auth_required:
        for problem in problems:
            logger.warning("SECURITY: %s", problem)
    # Ensure all ORM models are registered before create_all
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
    import app.domain.feature  # noqa: F401  # feature_snapshots
    init_db()
    # Restore the manual "block new entries" lock; a restart must not re-enable
    # trading silently.
    from app.services.account_risk_firewall import AccountRiskFirewall
    AccountRiskFirewall.load_persisted_block()
    # Register all provider adapters
    from app.services.providers.categories import register_all
    register_all()
    # Heal credentials written before per-tenant key derivation.
    from app.services.providers.key_migration import reencrypt_legacy_provider_credentials
    reencrypt_legacy_provider_credentials()
    # Background loops can run in-process (single-container) or in the
    # dedicated worker process (production compose).
    loops = None
    if settings.background_loops_enabled:
        from app.runtime_loops import BackgroundLoops

        loops = BackgroundLoops()
        await loops.start()
    yield
    if loops is not None:
        await loops.stop()


app = FastAPI(
    title="PulseDesk",
    description="AI-driven crypto quant trading API — v2.5",
    version="2.5.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

if settings.allowed_hosts and settings.allowed_hosts != ["*"]:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.allowed_hosts)
app.add_middleware(ErrorHandlerMiddleware)
app.add_middleware(
    RateLimitMiddleware,
    requests_per_minute=settings.rate_limit_per_minute,
    burst_size=settings.rate_limit_burst,
)
# Auth sits inside Logger (so 401s are logged) and inside CORS (so browsers get
# CORS headers on 401), but outside the routers.
app.add_middleware(AuthMiddleware)
app.add_middleware(RequestLoggerMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# v2.5 infrastructure
app.include_router(health.router)
app.include_router(commands.router)
app.include_router(ledger.router)

# Legacy routers (will be replaced module-by-module in Phase 01+)
app.include_router(strategies.router)
app.include_router(strategies_v2.router)
app.include_router(orders.router, dependencies=[Depends(require_platform_admin)])
app.include_router(dashboard.router)
app.include_router(backtest.router)
app.include_router(dryrun.router)
app.include_router(risk.router)
app.include_router(system.router)
app.include_router(auth.router)
app.include_router(invites.router)
app.include_router(members.router)
app.include_router(search.router)
app.include_router(notifications.router)
app.include_router(attribution.router)
app.include_router(sentiment.router)
app.include_router(sentiment.legacy_router)  # deprecated /sentiment alias
app.include_router(rag.router)
app.include_router(markets.router)
app.include_router(ai_research.router)
app.include_router(ai_research.cache_router)  # PRD §9.1 /api/ai-risk-cache
app.include_router(agent_signals.router)
app.include_router(ai_providers.router)
app.include_router(factor_research.router)
app.include_router(websocket.router)
app.include_router(growth.router)
app.include_router(live_small.router)
app.include_router(manipulation.router)
app.include_router(manipulation_ws_router)
app.include_router(trade_intents_router)
app.include_router(alert_rules_router)
app.include_router(canvas_ai_router)
app.include_router(billing_router)

# v2.5 new routers
app.include_router(signals_v2.router)
app.include_router(strategy_runs.router)
app.include_router(inference.router)
app.include_router(mcp.router)
app.include_router(admin_providers_router, dependencies=[Depends(require_superuser)])
app.include_router(admin_system_settings_router, dependencies=[Depends(require_superuser)])
app.include_router(admin_execution_profile_router, dependencies=[Depends(require_superuser)])
app.include_router(admin_sessions_router, dependencies=[Depends(require_superuser)])
app.include_router(admin_tenant_plan_router, dependencies=[Depends(require_superuser)])
app.include_router(admin_tenant_audit_router)
app.include_router(admin_tenant_usage_router)
app.include_router(admin_tenant_subscription_router)
app.include_router(admin_router, dependencies=[Depends(require_superuser)])
app.include_router(providers_ws_router)
app.include_router(decision.router)
app.include_router(emergency_v2.router)

# BFF aggregation layer
app.include_router(overview.router)
app.include_router(execution_bff.router)
app.include_router(reconciliation_bff.router)
app.include_router(risk_bff.router)
app.include_router(structure_bff.router)
app.include_router(market_structure_bff.router)
app.include_router(failure_clustering_bff.router)

# Shadow Strategy
app.include_router(shadow_strategy.router)

# Workflow layer
app.include_router(workflow.router)
app.include_router(trading.router)
app.include_router(trace.router)
app.include_router(state_leases.router)
app.include_router(canvas.router)
app.include_router(agents_router_module.router)

# Strategy workspace (7 endpoints, spec §6.1)
app.include_router(strategy_workspace_router)

# Risk lookup (binding picker for ⌘4 panel) — list active risk policy versions + capital pools
from app.routers.risk_lookup import router as risk_lookup_router
app.include_router(risk_lookup_router)
