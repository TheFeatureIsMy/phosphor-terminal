from fastapi import APIRouter, HTTPException
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
def attribution_summary(strategy_id: int):
    return get_attribution_summary(strategy_id)
@router.post("/feature-importance")
def feature_importance(body: FeatureImportanceRequest):
    return calculate_feature_importance(body.features, body.values, body.strategy_type)
@router.post("/decision-path")
def decision_path(body: DecisionPathRequest):
    return calculate_decision_path(body.features, body.values, body.thresholds)
