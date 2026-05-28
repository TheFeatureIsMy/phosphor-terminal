from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ai import ForecastRun, FactorResearchRun, FreqAIRun, GeneratedStrategyArtifact
from app.services.code_safety import scan_strategy_code
from app.services.forecasting import deterministic_forecast
from app.services.rag_service import generate_strategy


router = APIRouter(prefix="/api/ai", tags=["ai-phase3"])


class StrategyGenerationRequest(BaseModel):
    prompt: str = Field(..., min_length=1)
    risk_level: str = "medium"
    market: str = "crypto"


class ForecastRequest(BaseModel):
    symbol: str = Field(..., min_length=1)
    model: str = "timesfm"
    horizon: str = "7d"


class FactorResearchRequest(BaseModel):
    market: str = "crypto"
    universe: list[str] = ["BTC/USDT", "ETH/USDT"]
    factor_name: str = "momentum_quality"
    qlib_config: dict[str, Any] = {}


class FreqAITrainingRequest(BaseModel):
    strategy_id: Optional[int] = None
    model_name: str = "freqai-lightgbm"
    training_config: dict[str, Any] = {}


@router.post("/strategies/generate")
def generate_strategy_artifact(body: StrategyGenerationRequest, db: Session = Depends(get_db)):
    result = generate_strategy(body.prompt, body.risk_level, body.market)
    scan = scan_strategy_code(result["code"])
    artifact = GeneratedStrategyArtifact(
        prompt=body.prompt,
        risk_level=body.risk_level,
        market=body.market,
        strategy_name=result["strategy"]["name"],
        strategy_type=result["strategy"]["type"],
        code=result["code"],
        safety_status=scan["status"],
        safety_findings=scan["findings"],
    )
    db.add(artifact)
    db.commit()
    db.refresh(artifact)
    return {
        "id": artifact.id,
        "strategy": result["strategy"],
        "code": artifact.code,
        "safety_status": artifact.safety_status,
        "safety_findings": artifact.safety_findings,
        "explanation": result["explanation"],
        "context_used": result["context_used"],
    }


@router.post("/forecast")
def create_forecast(body: ForecastRequest, db: Session = Depends(get_db)):
    forecast = deterministic_forecast(body.symbol, body.model, body.horizon)
    run = ForecastRun(
        symbol=body.symbol,
        model=body.model,
        horizon=body.horizon,
        status="completed",
        points=forecast["points"],
        confidence=forecast["confidence"],
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    return run


@router.post("/factors/research")
def create_factor_research(body: FactorResearchRequest, db: Session = Depends(get_db)):
    metrics = {
        "ic_mean": 0.041,
        "ic_std": 0.18,
        "rank_ic": 0.057,
        "turnover": 0.32,
        "note": "Qlib adapter boundary; install optional Qlib runtime for full factor pipeline.",
    }
    run = FactorResearchRun(
        market=body.market,
        universe=body.universe,
        factor_name=body.factor_name,
        status="completed",
        metrics=metrics,
        qlib_config=body.qlib_config,
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    return run


@router.post("/freqai/train")
def create_freqai_run(body: FreqAITrainingRequest, db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    run = FreqAIRun(
        strategy_id=body.strategy_id,
        model_name=body.model_name,
        status="queued",
        training_config=body.training_config,
        metrics={},
        started_at=now,
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    return run
