from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ai import ForecastRun, FactorResearchRun, FreqAIRun, GeneratedStrategyArtifact
from app.routers.backtest import _generate_simulated_backtest
from app.schemas.api import BacktestRequest, BacktestResponse
from app.services.code_safety import scan_strategy_code
from app.services.forecasting import generate_forecast
from app.services.rag_service import generate_strategy
from app.services.factor_qlib import QlibAdapter
from app.services.strategy_registry import strategy_class_name, strategy_file_path, STRATEGY_DIR
from app.services.freqtrade_client import freqtrade_client


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
async def generate_strategy_artifact(body: StrategyGenerationRequest, db: Session = Depends(get_db)):
    result = await generate_strategy(body.prompt, body.risk_level, body.market)
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

    # Write strategy file to disk so Freqtrade can load it
    strategy_file_written = False
    if artifact.safety_status == "safe":
        try:
            class_name = strategy_class_name(artifact.id, artifact.strategy_name)
            STRATEGY_DIR.mkdir(parents=True, exist_ok=True)
            strategy_file_path(class_name).write_text(artifact.code, encoding="utf-8")
            strategy_file_written = True
        except (ValueError, OSError):
            pass

    return {
        "id": artifact.id,
        "strategy": result["strategy"],
        "code": artifact.code,
        "safety_status": artifact.safety_status,
        "safety_findings": artifact.safety_findings,
        "explanation": result["explanation"],
        "context_used": result["context_used"],
        "strategy_file_written": strategy_file_written,
    }


@router.post("/forecast")
async def create_forecast(body: ForecastRequest, db: Session = Depends(get_db)):
    forecast = await generate_forecast(body.symbol, body.model, body.horizon)
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


_qlib = QlibAdapter()


@router.post("/factors/research")
async def create_factor_research(body: FactorResearchRequest, db: Session = Depends(get_db)):
    result = await _qlib.research(body.market, body.universe, body.factor_name)
    metrics = result.get("metrics", {})
    run = FactorResearchRun(
        market=body.market,
        universe=body.universe,
        factor_name=body.factor_name,
        status=result.get("status", "completed"),
        metrics=metrics,
        qlib_config=body.qlib_config,
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    return run


@router.post("/strategies/{artifact_id}/backtest", response_model=BacktestResponse)
async def backtest_generated_strategy(artifact_id: int, db: Session = Depends(get_db)):
    artifact = db.query(GeneratedStrategyArtifact).filter(GeneratedStrategyArtifact.id == artifact_id).first()
    if not artifact:
        from fastapi import HTTPException
        raise HTTPException(404, "Generated strategy artifact not found")

    request = BacktestRequest(
        strategy_id=artifact_id,
        start_date="2025-01-01",
        end_date="2025-12-31",
        initial_capital=10000,
        symbols=[f"{artifact.market.upper()}/USDT"] if artifact.market else ["BTC/USDT"],
    )

    # Try real Freqtrade backtest first
    ft_result = await freqtrade_client.run_backtest({
        "strategy": artifact.strategy_name,
        "timerange": f"{request.start_date.replace('-', '')}-{request.end_date.replace('-', '')}",
        "stake_amount": request.initial_capital,
    })

    if "error" not in ft_result:
        data_source = {"source": "freqtrade", "simulated": False, "available": True, "detail": None}
        result = BacktestResponse(
            id=artifact_id,
            strategy_id=artifact_id,
            config=request.model_dump(),
            result=ft_result.get("result"),
            sharpe_ratio=ft_result.get("sharpe_ratio", 0),
            max_drawdown=ft_result.get("max_drawdown", 0),
            win_rate=ft_result.get("win_rate", 0),
            total_return=ft_result.get("total_return", 0),
            passed=ft_result.get("sharpe_ratio", 0) > 1.0,
            created_at=datetime.now(timezone.utc),
            data_source=data_source,
        )
    else:
        # Fall back to simulated backtest
        simulated = _generate_simulated_backtest(request)
        result = BacktestResponse(
            id=artifact_id,
            strategy_id=artifact_id,
            config=request.model_dump(),
            result=simulated["result"],
            sharpe_ratio=simulated["sharpe_ratio"],
            max_drawdown=simulated["max_drawdown"],
            win_rate=simulated["win_rate"],
            total_return=simulated["total_return"],
            passed=simulated["sharpe_ratio"] > 1.0,
            created_at=datetime.now(timezone.utc),
            data_source=simulated["data_source"],
        )

    artifact.backtest_id = artifact_id
    db.commit()
    return result


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


@router.get("/freqai/status")
def get_freqai_status(db: Session = Depends(get_db)):
    latest = db.query(FreqAIRun).order_by(FreqAIRun.created_at.desc()).first()
    if not latest:
        return {"status": "no_runs", "latest_run": None}
    return {"status": latest.status, "latest_run": {
        "id": latest.id,
        "model_name": latest.model_name,
        "strategy_id": latest.strategy_id,
        "status": latest.status,
        "started_at": latest.started_at,
        "completed_at": latest.completed_at,
    }}


@router.get("/freqai/runs")
def list_freqai_runs(db: Session = Depends(get_db)):
    runs = db.query(FreqAIRun).order_by(FreqAIRun.created_at.desc()).limit(50).all()
    return {
        "runs": [
            {
                "id": r.id,
                "strategy_id": r.strategy_id,
                "model_name": r.model_name,
                "status": r.status,
                "started_at": r.started_at,
                "completed_at": r.completed_at,
                "created_at": r.created_at,
            }
            for r in runs
        ],
        "total": len(runs),
    }
