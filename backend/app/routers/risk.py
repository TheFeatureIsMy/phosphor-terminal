from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.strategy import RiskEvent, CorrelationSnapshot
from app.schemas.api import RiskEventResponse, CorrelationResponse

router = APIRouter(prefix="/api", tags=["risk"])


def _mock_risk_events() -> list[dict]:
    return [
        {"id": 1, "event_type": "stop_loss", "strategy_id": 1, "severity": "medium", "description": "BTC/USDT 触发止损，浮亏超过5%", "action_taken": "自动平仓", "created_at": (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()},
        {"id": 2, "event_type": "correlation_warning", "strategy_id": None, "severity": "medium", "description": "BTC/USDT 与 ETH/USDT 相关系数 0.92，组合集中度过高", "action_taken": "建议减仓", "created_at": (datetime.now(timezone.utc) - timedelta(hours=2)).isoformat()},
        {"id": 3, "event_type": "api_error", "strategy_id": None, "severity": "high", "description": "Binance API 请求超时，已自动重试", "action_taken": "重连成功", "created_at": (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()},
    ]


def _mock_correlations() -> list[dict]:
    return [
        {"id": 1, "symbol_a": "BTC/USDT", "symbol_b": "ETH/USDT", "correlation": 0.92, "window_days": 30, "alert_level": "red", "created_at": datetime.now(timezone.utc).isoformat()},
        {"id": 2, "symbol_a": "BTC/USDT", "symbol_b": "SOL/USDT", "correlation": 0.78, "window_days": 30, "alert_level": "normal", "created_at": datetime.now(timezone.utc).isoformat()},
        {"id": 3, "symbol_a": "ETH/USDT", "symbol_b": "SOL/USDT", "correlation": 0.85, "window_days": 30, "alert_level": "yellow", "created_at": datetime.now(timezone.utc).isoformat()},
        {"id": 4, "symbol_a": "BTC/USDT", "symbol_b": "BNB/USDT", "correlation": 0.71, "window_days": 30, "alert_level": "normal", "created_at": datetime.now(timezone.utc).isoformat()},
    ]


@router.get("/risk/events", response_model=list[RiskEventResponse])
def list_risk_events(db: Session = Depends(get_db)):
    events = db.query(RiskEvent).order_by(RiskEvent.created_at.desc()).limit(50).all()
    if not events:
        return [RiskEventResponse(**e) for e in _mock_risk_events()]
    return events


@router.get("/portfolio/correlation", response_model=list[CorrelationResponse])
def list_correlations(db: Session = Depends(get_db)):
    corrs = db.query(CorrelationSnapshot).all()
    if not corrs:
        return [CorrelationResponse(**c) for c in _mock_correlations()]
    return corrs
