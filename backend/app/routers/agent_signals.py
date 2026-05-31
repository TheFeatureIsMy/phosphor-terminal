from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.agent_signal import AgentProfile, AgentSignal, AgentSignalScore
from app.schemas.agent_signal import AgentProfileCreate, AgentProfileResponse, AgentSignalCreate, AgentSignalResponse
from app.services.signal_scoring import score_signal_text


router = APIRouter(prefix="/api/agent-signals", tags=["agent-signals"])


@router.post("/agents", response_model=AgentProfileResponse, status_code=status.HTTP_201_CREATED)
def create_agent_profile(request: AgentProfileCreate, db: Session = Depends(get_db)):
    existing = db.query(AgentProfile).filter(AgentProfile.name == request.name).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail="Agent name already exists")
    agent = AgentProfile(name=request.name, kind=request.kind, description=request.description)
    db.add(agent)
    db.commit()
    db.refresh(agent)
    return agent


@router.get("/agents", response_model=list[AgentProfileResponse])
def list_agent_profiles(db: Session = Depends(get_db)):
    return db.query(AgentProfile).order_by(AgentProfile.created_at.desc()).limit(100).all()


@router.post("/signals", response_model=AgentSignalResponse, status_code=status.HTTP_201_CREATED)
def create_agent_signal(request: AgentSignalCreate, db: Session = Depends(get_db)):
    agent = db.query(AgentProfile).filter(AgentProfile.id == request.agent_id).first()
    if agent is None:
        raise HTTPException(status_code=404, detail="Agent not found")

    signal = AgentSignal(**request.model_dump())
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


@router.get("/signals", response_model=list[AgentSignalResponse])
def list_agent_signals(db: Session = Depends(get_db)):
    rows = db.query(AgentSignal).order_by(AgentSignal.created_at.desc()).limit(100).all()
    responses = []
    for row in rows:
        score = (
            db.query(AgentSignalScore)
            .filter(AgentSignalScore.signal_id == row.id)
            .order_by(AgentSignalScore.created_at.desc())
            .first()
        )
        item = AgentSignalResponse.model_validate(row)
        item.overall_score = score.overall_score if score else None
        responses.append(item)
    return responses
