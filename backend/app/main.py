from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import init_db
from app.routers import strategies, orders, dashboard, backtest, risk, system, auth


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="CyberQuant OS", version="1.0.0", lifespan=lifespan)

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


@app.get("/health")
def health():
    return {"status": "ok"}
