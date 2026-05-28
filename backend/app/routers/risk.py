from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.strategy import RiskEvent, CorrelationSnapshot, PortfolioStressTest
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
    return RiskRuleEvaluationResponse(status=status, created_events=created, dry_run=body.dry_run)


@router.get("/portfolio/correlation", response_model=list[CorrelationResponse])
def list_correlations(db: Session = Depends(get_db)):
    corrs = db.query(CorrelationSnapshot).all()
    if not corrs:
        return [CorrelationResponse(**c) for c in _mock_correlations()]
    return corrs


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
