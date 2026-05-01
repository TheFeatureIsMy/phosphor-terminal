from fastapi import APIRouter

from app.services.freqtrade_db import freqtrade_db
from app.schemas.api import DashboardKPIsResponse, EquityPointResponse

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


@router.get("/kpis", response_model=DashboardKPIsResponse)
def get_kpis():
    return freqtrade_db.get_kpis()


@router.get("/equity-curve", response_model=list[EquityPointResponse])
def get_equity_curve():
    return freqtrade_db.get_equity_curve()
