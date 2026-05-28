from datetime import datetime, timedelta, timezone

from fastapi import APIRouter

from app.services.freqtrade_db import freqtrade_db
from app.schemas.api import DashboardKPIsResponse, EquityPointResponse

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


def _simulated_kpis() -> dict:
    return {
        "total_pnl": 12840.75,
        "pnl_change_pct": 3.4,
        "sharpe_ratio": 1.48,
        "max_drawdown": 12.6,
        "win_rate": 63.5,
        "active_strategies": 3,
        "todays_trades": 8,
        "open_positions": 2,
        "data_source": freqtrade_db.source_status(simulated=True),
    }


def _simulated_equity_curve(days: int = 90) -> list[dict]:
    points = []
    value = 10000.0
    peak = value
    source = freqtrade_db.source_status(simulated=True)
    for i in range(days):
        cycle = ((i % 14) - 6) / 1000
        drift = 0.0018
        change = value * (drift + cycle)
        value = max(value + change, 5000)
        peak = max(peak, value)
        date = datetime.now(timezone.utc) - timedelta(days=days - i)
        points.append({
            "date": date.strftime("%Y-%m-%d"),
            "value": round(value, 2),
            "drawdown": round(((value - peak) / peak * 100) if peak > 0 else 0, 2),
            "data_source": source,
        })
    return points


@router.get("/kpis", response_model=DashboardKPIsResponse)
def get_kpis():
    result = freqtrade_db.get_kpis()
    if result.get("total_pnl", 0) == 0 and result.get("active_strategies", 0) == 0:
        return _simulated_kpis()
    result["data_source"] = freqtrade_db.source_status()
    return result


@router.get("/equity-curve", response_model=list[EquityPointResponse])
def get_equity_curve():
    result = freqtrade_db.get_equity_curve()
    if not result:
        return _simulated_equity_curve()
    source = freqtrade_db.source_status()
    for point in result:
        point["data_source"] = source
    return result
