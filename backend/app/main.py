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
    decision,
)
from app.routers import shadow_strategy
from app.routers import overview, execution_bff, reconciliation_bff, risk_bff, structure_bff
from app.routers import market_structure_bff, failure_clustering_bff
from app.routers import workflow
from app.routers.admin.providers import router as admin_providers_router
from app.routers.providers_ws import router as providers_ws_router
from app.services.providers.realtime.ccxt_ticker_stream import run_binance_ticker_stream


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging(level=settings.log_level, fmt=settings.log_format)
    init_db()
    # Start provider health scheduler
    from app.services.providers.scheduler import ProviderHealthScheduler

    sched = ProviderHealthScheduler()
    await sched.start()
    ticker_task = asyncio.create_task(run_binance_ticker_stream())
    yield
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
app.add_middleware(RateLimitMiddleware, requests_per_minute=60, burst_size=10)
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
app.include_router(rag.router)
app.include_router(markets.router)
app.include_router(ai_research.router)
app.include_router(agent_signals.router)
app.include_router(ai_providers.router)
app.include_router(factor_research.router)
app.include_router(websocket.router)
app.include_router(growth.router)
app.include_router(live_small.router)
app.include_router(manipulation.router)

# v2.5 new routers
app.include_router(signals_v2.router)
app.include_router(strategy_runs.router)
app.include_router(inference.router)
app.include_router(mcp.router)
app.include_router(admin_providers_router)
app.include_router(providers_ws_router)
app.include_router(decision.router)

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
