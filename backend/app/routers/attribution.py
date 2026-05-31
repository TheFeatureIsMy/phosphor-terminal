from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.strategy import AttributionReport, SlippageAttribution
from app.schemas.api import (
    AttributionReportCreate,
    AttributionReportResponse,
    SlippageAttributionCreate,
    SlippageAttributionResponse,
)
from app.services.slippage import calculate_slippage
from app.services.shap_service import (
    calculate_feature_importance,
    calculate_decision_path,
    get_attribution_summary,
)
from pydantic import BaseModel
from typing import List,  Optional
router = APIRouter(prefix="/attribution", tags=["attribution"])
class FeatureImportanceRequest(BaseModel):
    features: List[str]
    values: List[float]
    strategy_type: str = "ma_cross"
class DecisionPathRequest(BaseModel):
    features: List[str]
    values: List[float]
    thresholds: Optional[List[float]] = None
@router.get("/summary/{strategy_id}")
def attribution_summary(strategy_id: int, db: Session = Depends(get_db)):
    reports = db.query(AttributionReport).filter(AttributionReport.strategy_id == strategy_id).order_by(AttributionReport.created_at.desc()).limit(1).all()
    if reports:
        r = reports[0]
        return {
            "strategy_id": strategy_id,
            "feature_importance": {
                "features": list(r.feature_contributions.keys()) if r.feature_contributions else [],
                "importances": list(r.feature_contributions.values()) if r.feature_contributions else [],
                "base_value": 0.05,
                "strategy_type": "ma_cross",
            },
            "decision_path": {"path": [], "decision": "hold", "final_score": 0},
            "top_factors": r.top_loss_factors[:3] if r.top_loss_factors else [],
        }
    return get_attribution_summary(strategy_id)
@router.post("/feature-importance")
def feature_importance(body: FeatureImportanceRequest):
    return calculate_feature_importance(body.features, body.values, body.strategy_type)
@router.post("/decision-path")
def decision_path(body: DecisionPathRequest):
    return calculate_decision_path(body.features, body.values, body.thresholds)


@router.post("/reports", response_model=AttributionReportResponse, status_code=201)
def create_attribution_report(body: AttributionReportCreate, db: Session = Depends(get_db)):
    report = AttributionReport(**body.model_dump())
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


@router.get("/reports", response_model=list[AttributionReportResponse])
def list_attribution_reports(strategy_id: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(AttributionReport)
    if strategy_id is not None:
        query = query.filter(AttributionReport.strategy_id == strategy_id)
    return query.order_by(AttributionReport.created_at.desc()).limit(100).all()


@router.post("/slippage", response_model=SlippageAttributionResponse, status_code=201)
def create_slippage_attribution(body: SlippageAttributionCreate, db: Session = Depends(get_db)):
    calculated = calculate_slippage(
        body.signal_price,
        body.filled_price,
        body.spread_cost,
        body.market_impact,
        body.latency_cost,
    )
    item = SlippageAttribution(**body.model_dump(), **calculated)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/slippage", response_model=list[SlippageAttributionResponse])
def list_slippage_attribution(db: Session = Depends(get_db)):
    return db.query(SlippageAttribution).order_by(SlippageAttribution.created_at.desc()).limit(100).all()
