"""AI Research router — v1 legacy endpoints + v2 structured research pipeline.

v2 endpoints produce ResearchReport → SignalCandidate → StrategyDraft
with full ProviderTrace and human confirmation flow.
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.research import AIResearchRun
from app.models.research_v2 import (
    ResearchReport as ResearchReportModel,
    SignalCandidate as SignalCandidateModel,
    StrategyDraft as StrategyDraftModel,
)
from app.schemas.research import AIResearchRunCreate, AIResearchRunResponse
from app.schemas.research_v2 import (
    ConfirmDraftResponse,
    GenerateDraftRequest,
    ResearchReportResponse,
    ResearchRunCreateV2,
    SignalCandidateResponse,
    StrategyDraftResponse,
)
from app.services.llm_service import LLMService, create_llm_service_from_env
from app.services.research.research_service import ResearchService


router = APIRouter(prefix="/api/ai-research", tags=["ai-research"])

_llm_service: LLMService | None = None


def _get_llm_service() -> LLMService:
    global _llm_service
    if _llm_service is None:
        _llm_service = create_llm_service_from_env()
    return _llm_service


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ══════════════════════════════════════════════════════════════════════
# v1 Legacy endpoints (preserved for backward compatibility)
# ══════════════════════════════════════════════════════════════════════


def _execute_research_run(run_id: int, request: AIResearchRunCreate) -> None:
    from app.database import SessionLocal
    from app.services.tradingagents_adapter import (
        TradingAgentsConfig,
        run_tradingagents_analysis,
    )

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


# ══════════════════════════════════════════════════════════════════════
# v2 Structured Research endpoints
# ══════════════════════════════════════════════════════════════════════


@router.post("/v2/runs", response_model=AIResearchRunResponse, status_code=status.HTTP_201_CREATED)
def create_research_run_v2(request: ResearchRunCreateV2, db: Session = Depends(get_db)):
    """Create a v2 research run with structured output support."""
    run = AIResearchRun(
        symbol=request.symbol.upper(),
        asset_type=request.market,
        analysis_date=request.analysis_date,
        provider="llm_structured",
        runtime_config={
            "version": "v2",
            "selected_analysts": request.selected_analysts,
            "llm_provider": request.llm_provider,
            "deep_think_llm": request.deep_think_llm,
            "quick_think_llm": request.quick_think_llm,
            "max_debate_rounds": request.max_debate_rounds,
            "max_risk_rounds": request.max_risk_rounds,
            "timeframe": request.timeframe,
        },
        status="pending",
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    return run


@router.post("/v2/runs/{run_id}/execute", response_model=ResearchReportResponse)
async def execute_research_run_v2(run_id: int, db: Session = Depends(get_db)):
    """Execute a v2 research run → ResearchReport + SignalCandidates."""
    run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
    if run is None:
        raise HTTPException(status_code=404, detail="Research run not found")
    if run.status == "running":
        raise HTTPException(status_code=409, detail="Research run is already running")

    config = run.runtime_config or {}
    svc = ResearchService(db, _get_llm_service())

    report = await svc.execute_research(
        run=run,
        symbol=run.symbol,
        market=run.asset_type,
        timeframe=config.get("timeframe", "1d"),
        analysis_date=str(run.analysis_date),
        selected_analysts=config.get("selected_analysts", ["market", "social", "news", "fundamentals"]),
    )
    db.refresh(report)
    return report


@router.get("/v2/runs/{run_id}/report", response_model=ResearchReportResponse)
def get_research_report(run_id: int, db: Session = Depends(get_db)):
    """Get the ResearchReport for a completed run."""
    report = (
        db.query(ResearchReportModel)
        .filter(ResearchReportModel.run_id == run_id)
        .order_by(ResearchReportModel.created_at.desc())
        .first()
    )
    if report is None:
        raise HTTPException(status_code=404, detail="Research report not found for this run")
    return report


@router.get("/v2/runs/{run_id}/candidates", response_model=list[SignalCandidateResponse])
def get_signal_candidates(run_id: int, db: Session = Depends(get_db)):
    """Get SignalCandidates extracted from a research run's report."""
    report = (
        db.query(ResearchReportModel)
        .filter(ResearchReportModel.run_id == run_id)
        .first()
    )
    if report is None:
        raise HTTPException(status_code=404, detail="Research report not found for this run")

    candidates = (
        db.query(SignalCandidateModel)
        .filter(SignalCandidateModel.report_id == report.id)
        .order_by(SignalCandidateModel.created_at.desc())
        .all()
    )
    return candidates


@router.post(
    "/v2/candidates/{candidate_id}/generate-draft",
    response_model=StrategyDraftResponse,
    status_code=status.HTTP_201_CREATED,
)
async def generate_draft_from_candidate(
    candidate_id: str,
    body: GenerateDraftRequest | None = None,
    db: Session = Depends(get_db),
):
    """Generate a StrategyDraft from a SignalCandidate via LLM."""
    import uuid as _uuid

    try:
        cid = _uuid.UUID(candidate_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid candidate ID format")

    candidate = db.get(SignalCandidateModel, cid)
    if candidate is None:
        raise HTTPException(status_code=404, detail="Signal candidate not found")

    report = db.get(ResearchReportModel, candidate.report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Research report not found")

    svc = ResearchService(db, _get_llm_service())
    name_hint = body.name_hint if body else None
    draft = await svc.generate_draft(candidate, report, name_hint)
    db.refresh(draft)
    return draft


@router.get("/v2/drafts/{draft_id}", response_model=StrategyDraftResponse)
def get_strategy_draft(draft_id: str, db: Session = Depends(get_db)):
    """Get a StrategyDraft with its DSL and validation result."""
    import uuid as _uuid

    try:
        did = _uuid.UUID(draft_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid draft ID format")

    draft = db.get(StrategyDraftModel, did)
    if draft is None:
        raise HTTPException(status_code=404, detail="Strategy draft not found")
    return draft


@router.post("/v2/drafts/{draft_id}/confirm", response_model=ConfirmDraftResponse)
def confirm_strategy_draft(draft_id: str, db: Session = Depends(get_db)):
    """Confirm a valid StrategyDraft → create StrategyV2 + StrategyVersion(status=draft).

    Does NOT trigger backtest, dry-run, or any execution.
    """
    import uuid as _uuid

    try:
        did = _uuid.UUID(draft_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid draft ID format")

    draft = db.get(StrategyDraftModel, did)
    if draft is None:
        raise HTTPException(status_code=404, detail="Strategy draft not found")

    if not draft.dsl_valid:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot confirm draft with invalid DSL. Fix errors first.",
        )

    if draft.confirmed_strategy_id is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Draft already confirmed",
        )

    svc = ResearchService(db, _get_llm_service())
    try:
        strategy, version = svc.confirm_draft(draft)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))

    return ConfirmDraftResponse(
        strategy_id=strategy.id,
        version_id=version.id,
        version_no=version.version_no,
        status="draft",
    )
