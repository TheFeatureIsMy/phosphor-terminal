import asyncio
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.strategy import RiskEvent, CorrelationSnapshot, PortfolioStressTest
from app.routers.websocket import manager as ws_manager
from app.schemas.api import (
    CorrelationResponse,
    PortfolioStressTestCreate,
    PortfolioStressTestResponse,
    RiskEventResponse,
    RiskRuleEvaluationRequest,
    RiskRuleEvaluationResponse,
)
from app.services.risk_rules import evaluate_risk_rules

router = APIRouter(prefix="/api", tags=["risk"])


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
    return events


@router.post("/risk/evaluate", response_model=RiskRuleEvaluationResponse)
def evaluate_risk(body: RiskRuleEvaluationRequest, db: Session = Depends(get_db)):
    candidates = evaluate_risk_rules(body.model_dump())
    created: list[RiskEvent] = []
    if not body.dry_run:
        for candidate in candidates:
            event = RiskEvent(**candidate)
            db.add(event)
            created.append(event)
        db.commit()
        for event in created:
            db.refresh(event)
    else:
        now = datetime.now(timezone.utc)
        created = [RiskEvent(id=idx + 1, created_at=now, **candidate) for idx, candidate in enumerate(candidates)]

    status = "triggered" if created else "clear"
    if created and not body.dry_run:
        try:
            asyncio.create_task(ws_manager.broadcast("risk", {
                "type": "risk_event",
                "event_type": candidates[0].get("event_type", "unknown") if candidates else "unknown",
                "severity": candidates[0].get("severity", "medium") if candidates else "medium",
            }))
        except Exception:
            pass
    return RiskRuleEvaluationResponse(status=status, created_events=created, dry_run=body.dry_run)


@router.get("/portfolio/correlation", response_model=list[CorrelationResponse])
def list_correlations(db: Session = Depends(get_db)):
    from app.services.freqtrade_db import freqtrade_db
    corrs = db.query(CorrelationSnapshot).all()
    if corrs:
        source = freqtrade_db.source_status(simulated=False)
        return [
            CorrelationResponse(
                id=c.id, symbol_a=c.symbol_a, symbol_b=c.symbol_b,
                correlation=c.correlation, window_days=c.window_days,
                alert_level=c.alert_level, created_at=c.created_at,
                data_source=source,
            )
            for c in corrs
        ]
    computed = freqtrade_db.compute_correlations(days=30)
    if computed:
        source = freqtrade_db.source_status(simulated=False)
        saved = []
        for c in computed:
            row = CorrelationSnapshot(**c)
            db.add(row)
            saved.append(row)
        db.commit()
        for row in saved:
            db.refresh(row)
        return [
            CorrelationResponse(
                id=r.id, symbol_a=r.symbol_a, symbol_b=r.symbol_b,
                correlation=r.correlation, window_days=r.window_days,
                alert_level=r.alert_level, created_at=r.created_at,
                data_source=source,
            )
            for r in saved
        ]
    mock = _mock_correlations()
    source = freqtrade_db.source_status(simulated=True)
    for c in mock:
        c["data_source"] = source
    return [CorrelationResponse(**c) for c in mock]


@router.post("/portfolio/stress-tests", response_model=PortfolioStressTestResponse)
def create_stress_test(body: PortfolioStressTestCreate, db: Session = Depends(get_db)):
    stress_test = PortfolioStressTest(**body.model_dump())
    db.add(stress_test)
    db.commit()
    db.refresh(stress_test)
    return stress_test


@router.get("/portfolio/stress-tests", response_model=list[PortfolioStressTestResponse])
def list_stress_tests(db: Session = Depends(get_db)):
    return db.query(PortfolioStressTest).order_by(PortfolioStressTest.created_at.desc()).limit(50).all()


# --- Emergency Stop / Resume endpoints ---

from fastapi import HTTPException
from app.services.emergency_stop_service import EmergencyStopService
from app.schemas.emergency import EmergencyStopRequest, EmergencyStopResponse, EmergencyResumeRequest


@router.post("/risk/emergency-stop", response_model=EmergencyStopResponse)
def emergency_stop(body: EmergencyStopRequest, db: Session = Depends(get_db)):
    """Trigger emergency stop for one or all active strategy runs."""
    svc = EmergencyStopService(db)
    result = svc.stop(strategy_run_id=body.strategy_run_id, reason=body.reason)
    db.commit()
    return EmergencyStopResponse(
        stopped_runs=result["stopped_runs"],
        ledger_event_ids=result.get("ledger_event_ids", []),
        message=f"Stopped {result['stopped_count']} run(s). Reason: {result['reason']}",
    )


@router.post("/risk/emergency-resume")
def emergency_resume(body: EmergencyResumeRequest, db: Session = Depends(get_db)):
    """Resume from emergency stop."""
    svc = EmergencyStopService(db)
    try:
        result = svc.resume(body.strategy_run_id, reason=body.reason)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    db.commit()
    return result
