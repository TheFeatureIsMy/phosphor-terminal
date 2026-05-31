from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.research import AIResearchRun
from app.schemas.research import AIResearchRunCreate, AIResearchRunResponse
from app.services.tradingagents_adapter import (
    TradingAgentsConfig,
    run_tradingagents_analysis,
)


router = APIRouter(prefix="/api/ai-research", tags=["ai-research"])


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _execute_research_run(run_id: int, request: AIResearchRunCreate) -> None:
    from app.database import SessionLocal

    db = SessionLocal()
    try:
        run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
        if run is None:
            return
        run.status = "running"
        run.started_at = _utcnow()
        db.commit()

        config = TradingAgentsConfig(
            llm_provider=request.llm_provider,
            deep_think_llm=request.deep_think_llm,
            quick_think_llm=request.quick_think_llm,
            max_debate_rounds=request.max_debate_rounds,
            max_risk_rounds=request.max_risk_rounds,
        )
        result = run_tradingagents_analysis(
            symbol=request.symbol,
            analysis_date=request.analysis_date.isoformat(),
            asset_type=request.asset_type,
            selected_analysts=request.selected_analysts,
            config=config,
        )

        run.status = "completed"
        run.rating = result.get("rating")
        run.final_decision = result.get("final_decision")
        run.market_report = result.get("market_report")
        run.sentiment_report = result.get("sentiment_report")
        run.news_report = result.get("news_report")
        run.fundamentals_report = result.get("fundamentals_report")
        run.investment_debate = result.get("investment_debate") or {}
        run.risk_debate = result.get("risk_debate") or {}
        run.completed_at = _utcnow()
        db.commit()
    except Exception as exc:
        run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
        if run is not None:
            run.status = "failed"
            run.error_message = str(exc)
            run.completed_at = _utcnow()
            db.commit()
    finally:
        db.close()


@router.post("/runs", response_model=AIResearchRunResponse, status_code=status.HTTP_201_CREATED)
def create_research_run(request: AIResearchRunCreate, db: Session = Depends(get_db)):
    run = AIResearchRun(
        symbol=request.symbol.upper(),
        asset_type=request.asset_type,
        analysis_date=request.analysis_date,
        provider="tradingagents",
        runtime_config={
            "selected_analysts": request.selected_analysts,
            "llm_provider": request.llm_provider,
            "deep_think_llm": request.deep_think_llm,
            "quick_think_llm": request.quick_think_llm,
            "max_debate_rounds": request.max_debate_rounds,
            "max_risk_rounds": request.max_risk_rounds,
        },
        status="pending",
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    return run


@router.post("/runs/{run_id}/execute", response_model=AIResearchRunResponse)
def execute_research_run(run_id: int, request: AIResearchRunCreate, db: Session = Depends(get_db)):
    run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
    if run is None:
        raise HTTPException(status_code=404, detail="Research run not found")
    if run.status == "running":
        raise HTTPException(status_code=409, detail="Research run is already running")
    _execute_research_run(run_id, request)
    db.refresh(run)
    return run


@router.get("/runs", response_model=list[AIResearchRunResponse])
def list_research_runs(db: Session = Depends(get_db)):
    return db.query(AIResearchRun).order_by(AIResearchRun.created_at.desc()).limit(100).all()


@router.get("/runs/{run_id}", response_model=AIResearchRunResponse)
def get_research_run(run_id: int, db: Session = Depends(get_db)):
    run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
    if run is None:
        raise HTTPException(status_code=404, detail="Research run not found")
    return run


@router.post("/runs/{run_id}/publish-signal", status_code=status.HTTP_201_CREATED)
def publish_research_signal(run_id: int, db: Session = Depends(get_db)):
    from app.models.agent_signal import AgentProfile, AgentSignal, AgentSignalScore
    from app.schemas.agent_signal import AgentSignalResponse
    from app.services.signal_scoring import score_signal_text

    run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
    if run is None:
        raise HTTPException(status_code=404, detail="Research run not found")
    if run.status != "completed":
        raise HTTPException(status_code=409, detail="Research run is not completed")

    agent = db.query(AgentProfile).filter(AgentProfile.name == "AI Research Committee").first()
    if agent is None:
        agent = AgentProfile(
            name="AI Research Committee",
            kind="research",
            description="TradingAgents-backed multi-agent research committee",
        )
        db.add(agent)
        db.commit()
        db.refresh(agent)

    signal = AgentSignal(
        agent_id=agent.id,
        source="tradingagents",
        message_type="research",
        symbol=run.symbol,
        market=run.asset_type,
        rating=run.rating,
        content=run.final_decision or "",
        evidence={"research_run_id": run.id, "provider": run.provider},
        linked_research_run_id=run.id,
    )
    db.add(signal)
    db.commit()
    db.refresh(signal)

    scores = score_signal_text(signal.symbol, signal.direction, signal.content)
    score = AgentSignalScore(signal_id=signal.id, **scores)
    db.add(score)
    db.commit()
    db.refresh(score)

    response = AgentSignalResponse.model_validate(signal)
    response.overall_score = score.overall_score
    return response
