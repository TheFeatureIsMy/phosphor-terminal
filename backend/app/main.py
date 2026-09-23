import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import init_db
from app.logging import setup_logging
from app.middleware import ErrorHandlerMiddleware, RateLimitMiddleware, RequestLoggerMiddleware
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
from app.routers import overview, execution_bff, reconciliation_bff, risk_bff, structure_bff
from app.routers import market_structure_bff, failure_clustering_bff
from app.routers import workflow
from app.routers import trading
from app.routers import state_leases, canvas
from app.routers import agents as agents_router_module
from app.routers.admin.providers import router as admin_providers_router
from app.routers.admin.system_settings import router as admin_system_settings_router
from app.routers.admin import router as admin_router
from app.routers.providers_ws import router as providers_ws_router
from app.routers.strategy_workspace import router as strategy_workspace_router
from app.routers.manipulation_ws import router as manipulation_ws_router
from app.routers.trade_intents import router as trade_intents_router
from app.routers.alert_rules import router as alert_rules_router
from app.routers.canvas_ai import router as canvas_ai_router
from app.services.providers.realtime.ccxt_ticker_stream import run_binance_ticker_stream
from app.workers.worker_loop import CommandWorkerLoop
from app.workers.trade_sync_loop import TradeSyncLoop


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging(level=settings.log_level, fmt=settings.log_format)
    # Ensure all ORM models are registered before create_all
    import app.models.user  # noqa: F401
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
    # Register all provider adapters
    from app.services.providers.categories import register_all
    register_all()
    # Start provider health scheduler
    from app.services.providers.scheduler import ProviderHealthScheduler

    sched = ProviderHealthScheduler()
    await sched.start()
    # Start command worker loop
    cmd_worker = CommandWorkerLoop()
    await cmd_worker.start()
    # Start trade sync loop
    trade_sync = TradeSyncLoop()
    await trade_sync.start()
    ticker_task = asyncio.create_task(run_binance_ticker_stream())
    yield
    await trade_sync.stop()
    await cmd_worker.stop()
    ticker_task.cancel()
    try:
        await ticker_task
    except asyncio.CancelledError:
        pass
    await sched.stop()


app = FastAPI(
    title="PulseDesk",
    description="AI-driven crypto quant trading API — v2.5",
    version="2.5.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(ErrorHandlerMiddleware)
app.add_middleware(RateLimitMiddleware, requests_per_minute=600, burst_size=50)
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
app.include_router(orders.router)
app.include_router(dashboard.router)
app.include_router(backtest.router)
app.include_router(dryrun.router)
app.include_router(risk.router)
app.include_router(system.router)
app.include_router(auth.router)
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

# v2.5 new routers
app.include_router(signals_v2.router)
app.include_router(strategy_runs.router)
app.include_router(inference.router)
app.include_router(mcp.router)
app.include_router(admin_providers_router)
app.include_router(admin_system_settings_router)
app.include_router(admin_router)
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
app.include_router(state_leases.router)
app.include_router(canvas.router)
app.include_router(agents_router_module.router)

# Strategy workspace (7 endpoints, spec §6.1)
app.include_router(strategy_workspace_router)

# Risk lookup (binding picker for ⌘4 panel) — list active risk policy versions + capital pools
from app.routers.risk_lookup import router as risk_lookup_router
app.include_router(risk_lookup_router)
