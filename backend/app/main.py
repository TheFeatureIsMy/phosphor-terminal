import asyncio
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.database import init_db, engine as db_engine
from app.middleware import ErrorHandlerMiddleware, RateLimitMiddleware, RequestLoggerMiddleware
from app.models.strategy import RiskEvent
from app.routers import strategies, orders, dashboard, backtest, risk, system, auth, search, notifications, attribution, sentiment, rag, ai_phase3, markets, ai_research, agent_signals, ai_providers


async def _periodic_risk_evaluation():
    from app.database import SessionLocal
    while True:
        await asyncio.sleep(60)
        try:
            from app.services.freqtrade_db import freqtrade_db
            if freqtrade_db.is_available():
                positions = freqtrade_db.get_open_trades()
                for pos in positions:
                    pnl = float(pos["unrealized_pnl"]) if pos.get("unrealized_pnl") else 0
                    payload = {
                        "symbol": pos["symbol"],
                        "position_pnl_pct": pnl,
                        "take_profit_pct": pnl if pnl > 0 else None,
                        "drawdown_pct": abs(pnl) if pnl < 0 else 0,
                        "max_drawdown_pct": 10,
                    }
                    from app.services.risk_rules import evaluate_risk_rules
                    candidates = evaluate_risk_rules(payload)
                    if candidates:
                        db = SessionLocal()
                        for c in candidates:
                            db.add(RiskEvent(**c))
                        db.commit()
                        db.close()
        except Exception:
            pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    from app.services.freqai_worker import freqai_worker_loop
    risk_task = asyncio.create_task(_periodic_risk_evaluation())
    freqai_task = asyncio.create_task(freqai_worker_loop(db_engine))
    yield
    risk_task.cancel()
    freqai_task.cancel()
    for t in [risk_task, freqai_task]:
        try:
            await t
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title="PulseDesk",
    description="AI驱动的加密货币量化交易API",
    version="0.3.0",
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

app.include_router(strategies.router)
app.include_router(orders.router)
app.include_router(dashboard.router)
app.include_router(backtest.router)
app.include_router(risk.router)
app.include_router(system.router)
app.include_router(auth.router)
app.include_router(search.router)
app.include_router(notifications.router)
app.include_router(attribution.router)
app.include_router(sentiment.router)
app.include_router(rag.router)
app.include_router(ai_phase3.router)
app.include_router(markets.router)
app.include_router(ai_research.router)
app.include_router(agent_signals.router)
app.include_router(ai_providers.router)


@app.get("/health")
def health():
    return {"status": "ok"}
