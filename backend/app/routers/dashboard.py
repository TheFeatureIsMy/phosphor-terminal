import random
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter

from app.services.freqtrade_db import freqtrade_db
from app.schemas.api import DashboardKPIsResponse, EquityPointResponse

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


def _mock_kpis() -> dict:
    return {
        "total_pnl": round(random.uniform(5000, 25000), 2),
        "pnl_change_pct": round(random.uniform(-3, 8), 1),
        "sharpe_ratio": round(random.uniform(0.8, 2.5), 2),
        "max_drawdown": round(random.uniform(5, 20), 1),
        "win_rate": round(random.uniform(55, 75), 1),
        "active_strategies": random.randint(1, 4),
        "todays_trades": random.randint(2, 15),
        "open_positions": random.randint(1, 5),
    }


def _mock_equity_curve(days: int = 90) -> list[dict]:
    points = []
    value = 10000.0
    peak = value
    for i in range(days):
        change = value * random.uniform(-0.03, 0.04)
        value = max(value + change, 5000)
        peak = max(peak, value)
        date = datetime.now(timezone.utc) - timedelta(days=days - i)
        points.append({
            "date": date.strftime("%Y-%m-%d"),
            "value": round(value, 2),
            "drawdown": round(((value - peak) / peak * 100) if peak > 0 else 0, 2),
        })
    return points


@router.get("/kpis", response_model=DashboardKPIsResponse)
def get_kpis():
    result = freqtrade_db.get_kpis()
    if result.get("total_pnl", 0) == 0 and result.get("active_strategies", 0) == 0:
        return _mock_kpis()
    return result


@router.get("/equity-curve", response_model=list[EquityPointResponse])
def get_equity_curve():
    result = freqtrade_db.get_equity_curve()
    if not result:
        return _mock_equity_curve()
    return result
